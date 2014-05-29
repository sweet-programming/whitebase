require 'rubygems'
require 'sinatra'

if development?
  require 'sinatra/reloader'
end

get '/' do
  @now = Time.now.month

  
  erb :index
end
