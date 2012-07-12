# encoding: UTF-8
 
Sinatra::Application.default_options.merge!(
  :run => false,
  :env => :production,
  :raise_errors => true
)
 
log = File.new("sinatra.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)
 
require './app'
run Sinatra::Application