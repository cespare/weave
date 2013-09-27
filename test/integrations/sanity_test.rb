require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper"))

require "net/ssh"
require "weave"

TEST_HOSTS = [1, 2].map { |i| "weave#{i}" }

# Make sure the machines are up.
vagrant_status = `vagrant status`
unless $?.to_i.zero? && TEST_HOSTS.each { |host| vagrant_status =~ /#{host}\w+running/ }
  abort "You need to set up the test vagrant virtual machines to run the sanity test." \
  "Run 'vagrant up'."
end
# Make sure the user's ssh config has weave entries.
TEST_HOSTS.each do |host|
  config = Net::SSH::Config.load("~/.ssh/config", host)
  unless config["hostname"] == "127.0.0.1"
    abort "You need to add weave{1,2} to your ~/.ssh/config." \
      "You can use the output of 'vagrant ssh-config weave1'"
  end
end

class SanityTest < Minitest::Test
  ROOT_AT_TEST_HOSTS = TEST_HOSTS.map { |host| "root@#{host}" }
  SINGLE_TEST_HOST = ["root@#{TEST_HOSTS[0]}"]

  def test_executing_commands_simple
    output = Hash.new { |h, k| h[k] = [] }
    Weave.connect(ROOT_AT_TEST_HOSTS) do
      output[host] = run("echo 'hello'", :output => :capture)
    end
    TEST_HOSTS.each do |host|
      assert_empty output[host][:stderr]
      assert_equal "hello\n", output[host][:stdout]
    end
  end

  def test_executing_commands_raises_exception_with_non_zero_exit
    assert_raises(Weave::Error) do
      Weave.connect(SINGLE_TEST_HOST) { run("cd noexist", :output => :capture) }
    end

    results = {}
    Weave.connect(SINGLE_TEST_HOST) do
      results = run("exit 123", :output => :capture, :continue_on_failure => true)
    end
    assert_equal 123, results[:exit_code]
  end

  def test_in_serial_commands_run_in_expected_order
    output = ""
    Weave.connect(ROOT_AT_TEST_HOSTS, :serial => true) do
      command = (host == "weave1") ? "sleep 0.2; echo 'delayed'" : "echo 'on time'"
      output += run(command, :output => :capture)[:stdout]
    end
    assert_equal "delayed\non time\n", output
  end

  def test_in_parallel_commands_run_in_expected_order
    output = ""
    Weave.connect(ROOT_AT_TEST_HOSTS) do
      command = (host == "weave1") ? "sleep 0.2; echo 'delayed'" : "echo 'on time'"
      result = run(command, :output => :capture)
      output += result[:stdout]
    end
    assert_equal "on time\ndelayed\n", output
  end

  def test_on_a_connection_pool_basic_commands_should_run
    output = Hash.new { |h, k| h[k] = [] }
    Weave.connect(ROOT_AT_TEST_HOSTS).execute do
      output[host] = run("echo 'hello'", :output => :capture)
    end
    TEST_HOSTS.each do |host|
      assert_empty output[host][:stderr]
      assert_equal "hello\n", output[host][:stdout]
    end
  end

  def test_with_a_different_host_list_only_run_on_listed_hosts
    output = ""
    Weave::ConnectionPool.new.execute_with(SINGLE_TEST_HOST) do
      output += run("echo 'hello'", :output => :capture)[:stdout]
    end
    assert_equal "hello\n", output
  end
end
