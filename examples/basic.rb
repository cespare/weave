$:.unshift File.join(File.dirname(__FILE__), "../lib")

require "gossamer"

pool = Gossamer.connect(ARGV) do
  run "ls"
  run "sleep 3"
  run "ls"
end
