require 'rubygems'
require 'sinatra'
require 'rugged'
require "fssm"
require "redcarpet"
require_relative "white_base"

if development?
  require 'sinatra/reloader'
end

configure do
  whitebase = WhiteBase.new
end

get '/' do
  @now = Time.now.month
  erb :index
end

get '/files/:filename' do
  file_content = open("repos/#{params[:filename]}.md").read()
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
  markdown.render(file_content)
end
