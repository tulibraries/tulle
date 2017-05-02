require 'rubygems'
require 'sinatra'
require File.join(File.dirname(__FILE__), 'app/app.rb')
logger = Logger.new('/home/sinatra/log/sinatra.log')
STDOUT.reopen(logger)
STDERR.reopen(logger)

use Rack::CommonLogger, logger
run Tulle
