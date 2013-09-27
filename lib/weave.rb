require "net/ssh"
require "thread"

module Weave
  DEFAULT_THREAD_POOL_SIZE = 10

  # A Weave error.
  class Error < StandardError; end

  # @private
  COLORS = { :red => 1, :green => 2 }

  # Create a connection pool for an array of hosts. Each host must have a user specified (e.g.,
  # root@example.com). If a block is given, then the options are passed through to the underlying
  # ConnectionPool and the block is immediately run in the context of each connection. Otherwise, a pool is
  # returned.
  #
  # @see ConnectionPool#execute
  def self.connect(host_list, options = {}, &block)
    unless host_list.is_a? Array
      raise Weave::Error, "Must pass an array for host_list. Received: #{host_list.inspect}"
    end
    pool = ConnectionPool.new(host_list)
    if block_given?
      pool.execute(options, &block)
      pool.disconnect!
    else
      return pool
    end
  end

  # @private
  def self.color_string(string, color)
    return string unless STDOUT.isatty
    "\e[01;#{COLORS[color]+30}m#{string}\e[m"
  end

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
    # @param [Array] host_list the array of hosts, of the form user@host. You may leave off this argument, and
    # use #execute_with (instead of #execute) to specify the whole list of hosts each time.
    def initialize(host_list = [])
      @hosts = host_list
      @connections = host_list.reduce({}) { |pool, host| pool.merge(host => LazyConnection.new(host)) }
    end

    # Run a command over the connection pool. The block is evaluated in the context of LazyConnection.
    #
    # @param [Hash] options the various knobs
    # @option options [Array] :args the arguments to pass through to the block when it runs.
    # @option options [Fixnum or Symbol] :num_threads the number of concurrent threads to use to process this
    #     command, or :unlimited to use a thread for every host. Defaults to `DEFAULT_THREAD_POOL_SIZE`.
    # @option options [Boolean] :serial whether to process the command for each connection one at a time.
    # @option options [Fixnum] :batch_by if set, group the connections into batches of no more than this value
    #     and fully process each batch before starting the next one.
    def execute(options = {}, &block)
      execute_with(@hosts, options, &block)
    end

    # This is the same as #execute, except that host_list overrides the list of connections with which this
    # ConnectionPool was initialized. Any hosts in here that weren't already in the pool will be added.
    def execute_with(host_list, options = {}, &block)
      host_list.each { |host| @connections[host] ||= LazyConnection.new(host) }
      args = options[:args] || []
      num_threads = options[:num_threads] || DEFAULT_THREAD_POOL_SIZE
      if options[:serial]
        host_list.each { |host| @connections[host].self_eval args, &block }
      elsif options[:batch_by]
        num_threads = options[:batch_by] if num_threads == :unlimited
        host_list.each_slice(options[:batch_by]) do |batch|
          Weave.with_thread_pool(batch, num_threads) do |host, mutex|
            @connections[host].self_eval args, mutex, &block
          end
        end
      else
        num_threads = host_list.size if num_threads == :unlimited
        Weave.with_thread_pool(host_list, num_threads) do |host, mutex|
          @connections[host].self_eval args, mutex, &block
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

    # A thread-safe wrapper around Kernel.puts.
    def puts(*args) @mutex.synchronize { Kernel.puts(*args) } end

    # Run a command on this connection. This will open a connection if it's not already connected. The way the
    # output is presented is determined by the option `:output`. The default, `:output => :pretty`, prints
    # each line of output with the name of the host and whether the output is stderr or stdout. If `:output =>
    # :raw`, then the output will be passed as is directly back to `STDERR` or `STDOUT` as appropriate. If
    # `:output => :capture`, then this method puts the output into the result hash as
    # `{ :stdout => "...", :stderr => "..." }`.
    #
    # The result of this method is a hash containing either `:exit_code` (if the command exited normally) or
    # `:exit_signal` (if the command exited due to a signal). It also has `:stdout` and `:stderr` strings, if
    # `option[:output]` was set to `:capture`.
    #
    # If the option `:continue_on_failure` is set to true, then this method will continue as normal if the
    # command terminated via a signal or with a non-zero exit status. Otherwise (the default), these will
    # cause a `Weave::Error` to be raised.
    #
    # @param [Hash] options the output options
    # @option options [Symbol] :output the output format
    def run(command, options = {})
      options[:output] ||= :pretty
      @connection ||= Net::SSH.start(@host, @user)
      result = options[:output] == :capture ? { :stdout => "", :stderr => "" } : {}
      @connection.open_channel do |channel|
        channel.exec(command) do |_, success|
          unless success
            raise Error, "Could not run ssh command: #{command}"
          end

          channel.on_data do |_, data|
            append_or_print_output(result, data, :stdout, options)
          end

          channel.on_extended_data do |_, type, data|
            next unless type == 1
            append_or_print_output(result, data, :stderr, options)
          end

          channel.on_request("exit-status") do |_, data|
            code = data.read_long
            unless code.zero? || options[:continue_on_failure]
              raise Error, "[#{@host}] command finished with exit status #{code}: #{command}"
            end
            result[:exit_code] = code
          end

          channel.on_request("exit-signal") do |_, data|
            signal = data.read_long
            unless options[:continue_on_failure]
              signal_name = Signal.list.invert[signal]
              signal_message = signal_name ? "#{signal} (#{signal_name})" : "#{signal}"
              raise Error, "[#{@host}] command received signal #{signal_message}: #{command}"
            end
            result[:exit_signal] = signal
          end
        end
      end
      @connection.loop(0.05)
      result
    end

    # @private
    def append_or_print_output(result, data, stream, options)
      case options[:output]
      when :capture
        result[stream] << data
      when :raw
        out_stream = stream == :stdout ? STDOUT : STDERR
        out_stream.print data
      else
        stream_colored = case stream
                         when :stdout then Weave.color_string("out", :green)
                         when :stderr then Weave.color_string("err", :red)
                         end
        lines = data.split("\n").map { |line| "[#{stream_colored}|#{host}] #{line}" }.join("\n")
        puts lines
      end
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
    def self_eval(args, mutex = nil, &block)
      @mutex = mutex || NilMutex
      instance_exec(*args, &block)
      @mutex = NilMutex
    end

    # Disconnect, if connected.
    def disconnect()
      @connection.close if @connection
      @connection = nil
    end
  end
end
