require "net/ssh"
require "thread"
require "singleton"

module Gossamer
  DEFAULT_THREAD_POOL_SIZE = 10
  COLORS = {
    red: 1,
    green: 2,
    yellow: 3,
    blue: 4,
    magenta: 5,
    cyan: 6,
    white: 7,
    default: 8
  }

  # private
  def self.color_string(string, color) "\033[01;#{COLORS[color]+30}m#{string}\e[m" end

  def self.connect(host_list, options = {}, &block)
    options[:num_threads] ||= DEFAULT_THREAD_POOL_SIZE
    connections = host_list.reduce({}) { |pool, host| pool.merge(host => LazyConnection.new(host)) }
    if options[:serial]
      host_list.each { |host| connections[host].self_eval &block }
    elsif options[:batch_by]
      host_list.each_slice(options[:batch_by]) do |batch|
        Gossamer.with_thread_pool(batch, options[:num_threads]) do |host, mutex|
          connections[host].self_eval mutex, &block
        end
      end
    else
      Gossamer.with_thread_pool(host_list, options[:num_threads]) do |host, mutex|
        connections[host].self_eval mutex, &block
      end
    end
    connections.each_value(&:disconnect)
  end

  # Spread work, identified by a key, across multiple threads.
  # private
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

  def self.connect(host_list, options = {}, &block)
    pool = ConnectionPool.new(host_list)
    if block_given?
      pool.execute(options, &block)
      pool.disconnect!
    else
      return pool
    end
  end

  class ConnectionPool
    def initialize(host_list)
      @connections = host_list.reduce({}) { |pool, host| pool.merge(host => LazyConnection.new(host)) }
    end

    def execute(options = {}, &block)
      options[:num_threads] ||= DEFAULT_THREAD_POOL_SIZE
      if options[:serial]
        @connections.each_key { |host| @connections[host].self_eval &block }
      elsif options[:batch_by]
        @connections.each_key.each_slice(options[:batch_by]) do |batch|
          Gossamer.with_thread_pool(batch, options[:num_threads]) do |host, mutex|
            @connections[host].self_eval mutex, &block
          end
        end
      else
        Gossamer.with_thread_pool(@connections.keys, options[:num_threads]) do |host, mutex|
          @connections[host].self_eval mutex, &block
        end
      end
    end

    def disconnect!() @connections.each_value(&:disconnect) end
  end

  class NilMutex
    include Singleton
    def synchronize() yield end
  end

  class LazyConnection
    # private
    def self.user_and_host(host_string)
      user, at, host = host_string.rpartition("@")
      if [user, host].any? { |part| part.nil? || part.empty? }
        raise "Bad hostname (needs to be of the form user@host): #{host_string}"
      end
      [user, host]
    end

    # private
    def self_eval(mutex = nil, &block)
      @mutex = mutex || @nil_mutex
      instance_eval &block
      @mutex = @nil_mutex
    end

    attr_reader :user, :host

    def initialize(host_string)
      @user, @host = LazyConnection.user_and_host(host_string)
      @connection = nil
      @nil_mutex = NilMutex.instance
      @mutex = @nil_mutex
    end

    def run(command, options = {})
      @connection ||= Net::SSH.start(@host, @user)
      #@connection.exec(command) do |channel, stream, data|
        ##channel.send_data("\x03")
        #if options[:raw]
          #out_stream = stream == :stdout ? STDOUT : STDERR
          #out_stream.print data
          #next
        #end
        #stream_colored = stream == :stdout ? Gossamer.color_string("out", :green) : Gossamer.color_string("err", :red)
        #lines = data.split("\n").map { |line| "[#{stream_colored}|#{host}] #{line}" }.join("\n")
        #@mutex.synchronize { puts lines }
      #end
      @connection.open_channel do |channel|
        channel.request_pty
        channel.exec(command) do |channel, success|
          channel.on_data do |channel, data|
            puts "stdout -> #{data}"
            #channel.send_data("\x03\n")
          end
          channel.on_extended_data do |channel, type, data|
            puts "stderr -> #{data}"
          end
        end
      end
      @connection.loop(0.1)
    end

    # private
    def disconnect()
      @connection.close if @connection
      @connection = nil
    end
  end
end
