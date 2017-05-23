require 'rubygems'
require 'sinatra'
require File.join(File.dirname(__FILE__), 'app/app.rb')

map "/link-exchange" do
  run Tulle
end
