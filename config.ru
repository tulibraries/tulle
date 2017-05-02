require 'rubygems'
require 'sinatra'
require File.join(File.dirname(__FILE__), 'app/app.rb')
logger = File.new('/home/sinatra/log/sinatra.log', "a")
STDOUT.reopen(logger)
STDERR.reopen(logger)

run Tulle
