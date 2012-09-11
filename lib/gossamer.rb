require "net/ssh"
require "thread"

module Gossamer
  THREAD_POOL_SIZE = 10
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

  def self.color_string(string, color) "\033[01;#{COLORS[color]+30}m#{string}\e[m" end

  def self.connect(host_list, &block)
    connections = host_list.reduce({}) { |pool, host| pool.merge(host => LazyConnection.new(host)) }
    Gossamer.with_thread_pool(host_list) do |host, mutex|
      connections[host].instance_eval &block
    end
    connections.each_value(&:disconnect)
  end

  # Spread work, identified by a key, across multiple threads.
  def self.with_thread_pool(keys, &block)
    work_queue = Queue.new
    mutex = Mutex.new
    keys.each { |key| work_queue << key }

    threads = (1..THREAD_POOL_SIZE).map do |i|
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

  class LazyConnection
    def self.user_and_host(host_string)
      user, at, host = host_string.rpartition("@")
      if [user, host].any? { |part| part.nil? || part.empty? }
        raise "Bad hostname (needs to be of the form user@host): #{host_string}"
      end
      [user, host]
    end

    attr_reader :user, :host

    def initialize(host_string)
      @user, @host = LazyConnection.user_and_host(host_string)
      @connection = nil
    end

    def run(command)
      @connection ||= Net::SSH.start(@host, @user)
      @connection.exec(command) do |channel, stream, data|
        stream_colored = stream == :stdout ? Gossamer.color_string("out", :green) : Gossamer.color_string("err", :red)
        puts data.split("\n").map { |line| "[#{stream_colored}|#{host}] #{line}" }.join("\n")
      end
      @connection.loop(0.1)
    end

    def disconnect()
      @connection.close if @connection
      @connection = nil
    end
  end
end
