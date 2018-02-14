require 'rubygems'
require 'sinatra'
require 'fileutils'
require 'pathname'
require 'base64'
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
      haml :index
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

      file_content = open(Repos.path + "#{params[:splat].join('/')}.md").read()
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, hard_wrap: true, fenced_code_blocks: true)
      @content = markdown.render(file_content)
      haml :files
    end

    put '/files/*' do
      path = Repos.path + params[:splat].first
      data = Base64.decode64(request.body.read)

      path_list = params[:splat].first.split(?/)
      if (len = path_list.length) > 1
        dir = Repos.path + path_list.slice(0, len - 1).join(?/)
        FileUtils.mkdir_p dir
      end
      File.open(path, 'w') {|f| f.write(data) }
      Repos.open.commit
      "ok"
    end

    delete '/files/*' do
      path = Repos.path + params[:splat].first
      if File.exists?(path)
        File.delete(path)
        "ok"
      else
        status 404
        "file #{path} not found"
      end
    end
  end
end
