require 'net/http'
require 'eventmachine'
require 'listen'
require 'optparse'
require 'fileutils'
require 'pathname'
require 'base64'
require 'filemagic'
require 'net/http/post/multipart'

require_relative 'lib/whitebase/app_logger'

options = ARGV.getopts('Dd:u:c')

pid_file = File.expand_path('../.pid', __FILE__)
repos_dir = options['d'] || ENV['REPOS_DIR'] || File.expand_path('../repos/', __FILE__)
base_url = options['u'] || ENV['REMOTE_URL'] || 'http://localhost:9292'

if File.exist?(pid_file)
  if options["c"]
    exit 0
  end
  $stderr.puts "#{pid_file} is existing."
  exit 1
end

if options['D']
  Process.daemon(true)
  File.write(pid_file, Process.pid)
  FileUtils.touch './logs/whitebase.log'
  FileUtils.touch './logs/whitebase_err.log'
  $stdout = File.new('./logs/whitebase.log', 'a')
  $stderr = File.new('./logs/whitebase_err.log', 'a')

  trap :TERM do
    FileUtils.rm pid_file
  end
end

class FileObserver
  PERIOD = 5

  def initialize(base_url, repos_dir)
    WhiteBase::AppLogger.init
    @uri = URI.parse(base_url)
    @repos_dir = Pathname.new(repos_dir)
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @updated = {}
    @mutex = Mutex.new
  end

  def update(file)
    @mutex.synchronize do
      @updated[file] = Time.now
    end
  rescue Exception => e
    WhiteBase::AppLogger.exception(e)
  end

  def delete(file)
    @http.delete("/files/#{file}")
  end

  def put_file(file)
    path = @repos_dir + file
    m = FileMagic.mime.file(path.to_s).match(/(?<content_type>\w+\/\w+); \w+=(?<charset>[\w-]+)/)
    case m["charset"]
    when "utf-8"
      @http.put("/files/#{file}", Base64.encode64(path.read))
    else
      File.open(path) do |io|
        upload_io = UploadIO.new(io, m["content_type"], file)
        req = Net::HTTP::Put::Multipart.new("/files/#{file}", "file" => upload_io)
        @http.request(req)
      end
    end
  end

  def tick
    @mutex.synchronize do
      @updated.delete_if do |file, at|
        if at + PERIOD < Time.now
          begin
            put_file(file)
          rescue Exception => e
            WhiteBase::AppLogger.exception(e)
            next false
          end
          true
        else
          false
        end
      end
    end
  rescue Exception => e
    WhiteBase::AppLogger.exception(e)
  end

  def run
    EM.run do
      http = @http
      observer = self

      EM.add_periodic_timer(PERIOD) do
        observer.tick
      end

      listen = Listen.to(@repos_dir) do |modified, added, removed|
        modified.reject{|path| path.end_with?(?~)}.each do |path|
          relative_path = Pathname.new(path).relative_path_from(@repos_dir)
          WhiteBase::AppLogger.info "UPDATE: #{relative_path}"
          observer.update(relative_path)
        end

       added.reject{|path| path.end_with?(?~)}.each do |path|
          relative_path = Pathname.new(path).relative_path_from(@repos_dir)
          WhiteBase::AppLogger.info "CREATE: #{relative_path}"
          observer.update(relative_path)
        end

        removed.reject{|path| path.end_with?(?~)}.each do |path|
          relative_path = Pathname.new(path).relative_path_from(@repos_dir)
          WhiteBase::AppLogger.info "DELETE: #{relative_path}"
          observer.delete(relative_path)
        end
      end

      listen.start
    end
  end
end

Thread.new do
  uri = URI.parse(base_url)
  http = Net::HTTP.new(uri.host, uri.port)

  loop do
    http.post("/keepalive", "")
  rescue Exception
  ensure
    sleep(60)
  end
end

FileObserver.new(base_url, repos_dir).run
