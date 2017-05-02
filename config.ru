require 'rubygems'
require 'sinatra'
require File.join(File.dirname(__FILE__), 'app/app.rb')
logger = Logger.new(File.join(File.dirname(__FILE__), 'log/sinatra.log'))
STDOUT.reopen(log)
STDERR.reopen(log)

use Rack::CommonLogger, logger
run Tulle
