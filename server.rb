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
    EXTENSIONS = %w(pdf png gif jpg jpeg)

    configure do
      enable :sessions
      set :auth, Authorization.new(File.expand_path('../.auth', __FILE__))
      set :markdown, Redcarpet::Markdown.new(Redcarpet::Render::HTML,
                                             autolink: true,
                                             tables: true,
                                             hard_wrap: true,
                                             fenced_code_blocks: true)
      set :last_access, {}
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

      def logger
        request.logger
      end
    end

    get '/' do
      authorize or return

      @year = Time.now.year
      @month = Time.now.month
      haml :index
    end

    get /\/(\d{4})-(\d{2})/ do
      authorize or return

      (@year, @month) = params['captures']
      haml :index
    end

    get /\/((\d{4})-(\d{2})-(\d{2}))/ do
      authorize or return

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
      haml :login, layout: false
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

    post "/keepalive" do
      settings.last_access[request.ip] = Time.now
    end

    get "/share/:id" do
      (name, id) = File.readlines(Repos.path + "share/.hash").map(&:split).find{|name, id| id == params[:id] }
      path = Repos.path + "share/#{name}.md"

      unless path.exist?
        return "file not found"
      end

      file_content = open(path).read()
      @content = settings.markdown.render(file_content)
      haml :docs
    end

    get "/docs" do
      redirect "/docs/"
    end

    get '/docs/*' do
      authorize or return

      @last_access = settings.last_access[request.ip]
      @pathname = params[:splat].first.sub(/\.md$/, '')

      return call env.merge("PATH_INFO" => "/files/#{@pathname}") if @pathname.match?(/\.#{EXTENSIONS.map{|ext| "(#{ext})"}.join("|")}$/)

      @dirpath = Pathname.new("/docs") + File.dirname(@pathname)
      @basepath = Pathname.new("/docs") + @pathname
      @filepath = Pathname.new("/files") + "#{@pathname}.md"
      dir = Repos.path + @pathname
      path = Repos.path + "#{@pathname}.md"

      unless path.exist? || dir.directory?
        return "file not found"
      end

      @content = ""

      if dir.directory?
        @filelist = Dir.glob(dir + "*.md").map{|n| File.basename(n, ".md") }.reject{|n| n == "index" }.sort
        @dirlist = Dir.children(dir).select{|n| File.directory?(dir + n) && !n.start_with?(".") }.sort
        if (dir + "index.md").exist?
          index_content = open(dir + "index.md").read()
          @content = settings.markdown.render(index_content)
          end
      end

      if path.exist?
        file_content = open(path).read()
        @content += settings.markdown.render(file_content)
      end

      haml :docs
    end

    get '/files/*' do
      authorize or return

      path = Repos.path.join(*params[:splat])

      unless path.exist?
        return "file not found"
      end

      send_file path
    end

    put '/files/*' do
      if params[:file]
        logger.info "put file: #{params[:file]}"
        data = params[:file][:tempfile].read
      else
        data = Base64.decode64(request.body.read)
      end
      path = Repos.path.join(*params[:splat])
      unless File.directory?(path.dirname)
        FileUtils.mkdir_p path.dirname
      end

      File.open(path, 'w') {|f| f.write(data) }
      begin
        Repos.open.commit
      rescue => e
        logger.error e
      end
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
