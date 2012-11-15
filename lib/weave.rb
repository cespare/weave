require "net/ssh"
require "thread"

module Weave
  DEFAULT_THREAD_POOL_SIZE = 10

  # @private
  COLORS = {
    red: 1,
    green: 2,
  }

  # Create a connection pool for an array of hosts. Each host must have a user specified (e.g.,
  # root@example.com). If a block is given, then the options are passed through to the underlying
  # ConnectionPool and the block is immediately run in the context of each connection. Otherwise, a pool is
  # returned.
  #
  # @see ConnectionPool#execute
  def self.connect(host_list, options = {}, &block)
    pool = ConnectionPool.new(host_list)
    if block_given?
      pool.execute(options, &block)
      pool.disconnect!
    else
      return pool
    end
  end

  # @private
  def self.color_string(string, color) "\e[01;#{COLORS[color]+30}m#{string}\e[m" end

  # Spread work, identified by a key, across multiple threads.
  # @private
  def self.with_thread_pool(keys, thread_pool_size, &block)
    work_queue = Queue.new
    mutex = Mutex.new
    keys.each { |key| work_queue << key }

    threads = (1..thread_pool_size).map do |i|
      Thread.new do
        begin
          while (key = work_queue.pop(true))
            yield key, mutex
          end
        rescue ThreadError # Queue is empty
        end
      end
    end
    threads.each(&:join)
    nil
  end

  # A pool of SSH connections. Operations over the pool may be performed in serial or in parallel.
  class ConnectionPool
    # @param [Array] host_list the array of hosts, of the form user@host
    def initialize(host_list)
      @connections = host_list.reduce({}) { |pool, host| pool.merge(host => LazyConnection.new(host)) }
    end

    # Run a command over the connection pool. The block is evaluated in the context of LazyConnection.
    #
    # @param [Hash] options the various knobs
    # @option options [Fixnum] :num_threads the number of concurrent threads to use to process this command.
    #     Defaults to `DEFAULT_THREAD_POOL_SIZE`.
    # @option options [Boolean] :serial whether to process the command for each connection one at a time.
    # @option options [Fixnum] :batch_by if set, group the connections into batches of no more than this value
    #     and fully process each batch before starting the next one.
    def execute(options = {}, &block)
      options[:num_threads] ||= DEFAULT_THREAD_POOL_SIZE
      if options[:serial]
        @connections.each_key { |host| @connections[host].self_eval &block }
      elsif options[:batch_by]
        @connections.each_key.each_slice(options[:batch_by]) do |batch|
          Weave.with_thread_pool(batch, options[:num_threads]) do |host, mutex|
            @connections[host].self_eval mutex, &block
          end
        end
      else
        Weave.with_thread_pool(@connections.keys, options[:num_threads]) do |host, mutex|
          @connections[host].self_eval mutex, &block
        end
      end
    end

    # Disconnect all open connections.
    def disconnect!() @connections.each_value(&:disconnect) end
  end

  # @private
  module NilMutex
    extend self
    def synchronize() yield end
  end

  # An SSH connection which isn't established until it's needed.
  class LazyConnection
    # The username for the ssh connection
    attr_reader :user
    # The hostname for the ssh connection
    attr_reader :host

    # @param [String] host_string the host of the form user@host
    def initialize(host_string)
      @user, @host = self.class.user_and_host(host_string)
      @connection = nil
      @mutex = NilMutex
    end

    # Run a command on this connection. This will open a connection if it's not already connected. The way the
    # output is presented is determined by the option `:output`. The default, `:output => :pretty`, prints
    # each line of output with the name of the host and whether the output is stderr or stdout. If `:output =>
    # :raw`, then the output will be passed as is directly back to `STDERR` or `STDOUT` as appropriate. If
    # `:output => :capture`, then this method returns the output in a hash of the form
    # `{ :stdout => [...], :stderr => [...] }`.
    #
    # @param [Hash] options the output options
    # @option options [Symbol] :output the output format
    def run(command, options = {})
      options[:output] ||= :pretty
      @connection ||= Net::SSH.start(@host, @user)
      output = { :stderr => [], :stdout => [] }
      @connection.exec(command) do |channel, stream, data|
        case options[:output]
        when :capture
          output[stream] << data
        when :raw
          out_stream = stream == :stdout ? STDOUT : STDERR
          out_stream.print data
        else
          stream_colored = case stream
                           when :stdout then Weave.color_string("out", :green)
                           when :stderr then Weave.color_string("err", :red)
                           end
          lines = data.split("\n").map { |line| "[#{stream_colored}|#{host}] #{line}" }.join("\n")
            @mutex.synchronize { puts lines }
        end
      end
      @connection.loop(0.1)
      (options[:output] == :capture) ? output : nil
    end

    # @private
    def self.user_and_host(host_string)
      user, at, host = host_string.rpartition("@")
      if [user, host].any? { |part| part.nil? || part.empty? }
        raise "Bad hostname (needs to be of the form user@host): #{host_string}"
      end
      [user, host]
    end

    # @private
    def self_eval(mutex = nil, &block)
      @mutex = mutex || NilMutex
      instance_eval &block
      @mutex = NilMutex
    end

    # Disconnect, if connected.
    def disconnect()
      @connection.close if @connection
      @connection = nil
    end
  end
end
