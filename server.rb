require 'rubygems'
require 'sinatra'
require 'fileutils'
require 'redcarpet'
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
      set :markdown, Redcarpet::Markdown.new(Redcarpet::Render::HTML,
                                             autolink: true,
                                             tables: true,
                                             hard_wrap: true,
                                             fenced_code_blocks: true)
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

      @year = Time.now.year
      @month = Time.now.month
      haml :index
    end

    get /\/(\d{4})-(\d{2})/ do
      (@year, @month) = params['captures']
      haml :index
    end

    get /\/((\d{4})-(\d{2})-(\d{2}))/ do
      @date = Date.parse(params['captures'][0])
      @prev = @date - 1
      @next = @date + 1

      path = Repos.path + "diary/#{@date}.md"

      if path.exist?
        file_content = open(path).read()
        @content = settings.markdown.render(file_content)
      else
        @content = "<p class='message'>file not found</p>"
      end
      haml :diary
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

    get '/docs/*' do
      authorize or return

      path = Repos.path + "#{params[:splat].join('/')}.md"

      unless path.exist?
        return "file not found"
      end

      file_content = open(path).read()
      @content = settings.markdown.render(file_content)
      haml :docs
    end

    get '/files/*' do
      authorize or return

      path = Repos.path + "#{params[:splat].join('/')}"

      unless path.exist?
        return "file not found"
      end

      send_file path
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
