require 'rubygems'
require 'sinatra'
require 'logger'
require File.join(File.dirname(__FILE__), 'app/app.rb')

log = File.new("log/sinatra.log", "a+")
$stdout.reopen(log)
$stderr.reopen(log)
$stderr.sync = true
$stdout.sync = true

run Tulle
