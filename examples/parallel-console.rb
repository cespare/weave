$:.unshift File.join(File.dirname(__FILE__), "../lib")

require "readline"
require "weave"

usage = <<-EOS
Usage:
  $ ruby parallel-console.rb user@host1 user@host2 ...
EOS

abort usage if ARGV.empty?

$stty_state = `stty -g`.chomp
$pool = Weave.connect(ARGV)

prompt = ">>> "
while command = Readline.readline(prompt, true)
  prompt = ">>> "
  break unless command # ctrl-D
  command.chomp!
  next if command.empty?
  break if ["exit", "quit"].include? command
  bad_exit = false
  $pool.execute do
    result = run(command, :continue_on_failure => true)
    bad_exit = result[:exit_code] && result[:exit_code] != 0
    bad_exit ||= result[:exit_signal]
  end
  prompt = "!!! " if bad_exit
end

$pool.disconnect!
`stty #{$stty_state}`
puts "Bye."
