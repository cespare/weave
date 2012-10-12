require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper"))

require "net/ssh"
require "weave"

class SanityTest < Scope::TestCase
  TEST_HOSTS = [1, 2].map { |i| "weave#{i}" }
  ROOT_AT_TEST_HOSTS = TEST_HOSTS.map { |host| "root@#{host}" }

  setup_once do
    # Make sure the machines are up.
    vagrant_status = `bundle exec vagrant status`
    unless $?.to_i.zero? && TEST_HOSTS.each { |host| vagrant_status =~ /#{host}\w+running/ }
      abort "You need to set up the test vagrant virtual machines to run the sanity test." \
            "Run 'bundle exec vagrant up'."
    end
    # Make sure the user's ssh config has weave entries.
    TEST_HOSTS.each do |host|
      config = Net::SSH::Config.load("~/.ssh/config", host)
      unless config["hostname"] == "127.0.0.1"
        abort "You need to add weave{1,2} to your ~/.ssh/config." \
              "You can use the output of 'bundle exec vagrant ssh-config weave1'"
      end
    end
  end

  context "executing some commands" do
    should "run some simple commands" do
      output = Hash.new { |h, k| h[k] = [] }
      Weave.connect(ROOT_AT_TEST_HOSTS) do
        output[host] = run("echo 'hello'", :output => :capture)
      end
      TEST_HOSTS.each do |host|
        assert_empty output[host][:stderr]
        assert_equal ["hello\n"], output[host][:stdout]
      end
    end

    context "in serial" do
      should "run some commands in the expected order" do
        output = []
        Weave.connect(ROOT_AT_TEST_HOSTS, :serial => true) do
          command = (host == "weave1") ? "sleep 0.2; echo 'delayed'" : "echo 'on time'"
          output += run(command, :output => :capture)[:stdout]
        end
        assert_equal ["delayed\n", "on time\n"], output
      end
    end

    context "in parallel" do
      should "run some commands in the expected order" do
        output = []
        Weave.connect(ROOT_AT_TEST_HOSTS) do
          command = (host == "weave1") ? "sleep 0.2; echo 'delayed'" : "echo 'on time'"
          result = run(command, :output => :capture)
          output += result[:stdout]
        end
        assert_equal ["on time\n", "delayed\n"], output
      end
    end

    context "on a connection pool" do
      should "run basic commands" do
        output = Hash.new { |h, k| h[k] = [] }
        Weave.connect(ROOT_AT_TEST_HOSTS).execute do
          output[host] = run("echo 'hello'", :output => :capture)
        end
        TEST_HOSTS.each do |host|
          assert_empty output[host][:stderr]
          assert_equal ["hello\n"], output[host][:stdout]
        end
      end
    end
  end
end
