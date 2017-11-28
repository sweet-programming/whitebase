require 'rubygems'
require 'sinatra'
require 'redcarpet'
require 'fileutils'
require 'pathname'
require_relative './lib/whitebase/authorization'
require_relative './lib/whitebase/user'
require_relative './lib/whitebase/repos'

if development?
  require 'sinatra/reloader'
end

module WhiteBase
  class Server < Sinatra::Base
    configure do
      enable :sessions
      set :repos, Pathname.new(File.expand_path('../repos', __FILE__))
      set :auth, Authorization.new(File.expand_path('../.auth', __FILE__))
    end

    helpers do
      def authorize
        access_token = headers[:access_token] || session[:access_token]
        unless access_token && settings.auth.authorize(access_token)
          redirect to("/login")
          return false
        end
        true
      end
    end

    get '/' do
      authorize or return

      @now = Time.now.month
      erb :index
    end

    get '/login' do
      haml :login
    end

    post '/login' do
      if access_token = settings.auth.login(params[:loginname], params[:password])
        session[:access_token] = access_token
        redirect to('/')
      else
        @message = "Login failed username: #{params[:loginname]}"
        haml :login
      end
    end

    get '/files/*' do
      authorize or return

      file_content = open(settings.repos + "#{params[:splat].join('/')}.md").read()
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, hard_wrap: true)
      @content = markdown.render(file_content)
      erb :files
    end

    put '/files/*' do
      path = settings.repos + params[:splat].join('/')
      data = request.body.read
      if data.empty?
        FileUtils.touch(path)
      else
        File.open(path, 'w') {|f| f.write(data) }
      end
      Repos.new(settings.repos).commit
      "ok"
    end
  end
end
