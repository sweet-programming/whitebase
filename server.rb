require 'rubygems'
require 'sinatra'

if development?
  require 'sinatra/reloader'
end

get '/' do
  erb :index
end
