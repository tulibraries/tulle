require 'rubygems'
require 'sinatra'
require 'logger'
require File.join(File.dirname(__FILE__), 'app/app.rb')

enable :logging, :dump_errors, :raise_errors

run Tulle
