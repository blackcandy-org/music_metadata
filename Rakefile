require "bundler/gem_tasks"
require "rake/testtask"
require "standard/rake"

Rake::TestTask.new do |task|
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
end

task default: [:test, :standard]
