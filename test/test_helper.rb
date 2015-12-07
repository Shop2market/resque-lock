require 'bundler/setup'
require 'resque-status'
require 'resque-lock'

require 'minitest/autorun'
require 'mocha/setup'

#
# make sure we can run redis
#

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end

#
# start our own redis when the tests start,
# kill it when they end
#


class << Minitest
  def exit(*args)
    pid = `ps -e -o pid,command | grep [r]edis.*9736`.split(" ")[0]
    puts "Killing test redis server..."
    Process.kill("KILL", pid.to_i)
    super
  end
end

dir = File.expand_path("../", __FILE__)
puts "Starting redis for testing at localhost:9736..."
result = `rm -f #{dir}/dump.rdb && redis-server #{dir}/redis-test.conf`
raise "Redis failed to start: #{result}" unless $?.success?
Resque.redis = 'localhost:9736/1'
