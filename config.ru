require 'rubygems'
require 'bundler'

Bundler.require

require File.expand_path('camera_dashboard.rb')
run Sinatra::Application
