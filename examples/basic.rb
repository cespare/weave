$:.unshift File.join(File.dirname(__FILE__), "../lib")

require "weave"

pool = Weave.connect(ARGV) do
  run "ls"
end
