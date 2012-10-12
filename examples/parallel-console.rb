$:.unshift File.join(File.dirname(__FILE__), "../lib")

require "readline"
require "gossamer"

usage = <<-EOS
Usage:
  $ ./parallel-ssh user@host1 user@host2 ...
EOS

abort usage if ARGV.empty?

$stty_state = `stty -g`.chomp
$pool = Gossamer.connect(ARGV)

while command = Readline.readline(">>> ", true)
  break unless command # ctrl-D
  command.chomp!
  next if command.empty?
  break if ["exit", "quit"].include? command
  $pool.execute { run command }
end

$pool.disconnect!
`stty #{$stty_state}`
puts "Bye."
