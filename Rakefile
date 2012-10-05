require 'bundler/gem_tasks'

require 'rake'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task 'testversions' do
  ENV['SHOULDA_VERSION'] = '2.11.3'
  fail unless system "bundle update"
  fail unless system "rake test"
  ENV['SHOULDA_VERSION'] = '3.1.1'
  fail unless system "bundle update"
  fail unless system "rake test"
end

task :default => :testversions
