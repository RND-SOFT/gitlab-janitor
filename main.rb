#!/usr/bin/env ruby
require 'active_support/all'

STDOUT.sync = true
STDERR.sync = true

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

loop do
  puts "hard work"
  sleep 5
end