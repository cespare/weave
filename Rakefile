#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rake/testtask"

task :test => ["test:integrations"]

namespace :test do
  Rake::TestTask.new(:integrations) do |task|
    task.test_files = FileList["test/integrations/**/*.rb"]
  end
end
