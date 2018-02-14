require 'net/http'
require 'eventmachine'
require 'fssm'
require 'optparse'
require 'fileutils'
require 'base64'
require_relative 'lib/whitebase/app_logger'

options = ARGV.getopts('Dd:u:')

pid_file = File.expand_path('../.pid', __FILE__)
repos_dir = options['d'] || ENV['REPOS_DIR'] || File.expand_path('../repos/', __FILE__)
base_url = options['u'] || ENV['REMOTE_URL'] || 'http://localhost:9292'

if options['D']
  Process.daemon(true)
  File.write(pid_file, Process.pid)
  FileUtils.touch './logs/whitebase.log'
  FileUtils.touch './logs/whitebase_err.log'
  $stdout = File.new('./logs/whitebase.log', 'a')
  $stderr = File.new('./logs/whitebase_err.log', 'a')
end

class FileObserver
  PERIOD = 5

  def initialize(base_url, repos_dir)
    WhiteBase::AppLogger.init
    @uri = URI.parse(base_url)
    @repos_dir = repos_dir
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

  def tick
    @mutex.synchronize do
      @updated.delete_if do |file, at|
        if at + PERIOD < Time.now
          begin
            @http.put("/files/#{file}", Base64.encode64(File.read(@repos_dir + ?/ + file)))
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

      monitor = FSSM::Monitor.new
      monitor.path(@repos_dir) do
        glob "**/*"

        update do |base, file|
          break if file.end_with?(?~)
          WhiteBase::AppLogger.info "UPDATE: #{base}/#{file}"
          observer.update(file)
        end

        create do |base, file|
          break if file.end_with?(?~)
          WhiteBase::AppLogger.info "CREATE: #{base}/#{file}"
          observer.update(file)
        end

        delete do |base, file|
          break if file.end_with?(?~)
          WhiteBase::AppLogger.info "DELETE: #{base}/#{file}"
          observer.delete(file)
        end

        EM.defer do
          begin
            monitor.run
          rescue
            retry
          end
        end
      end
    end
  end
end

FileObserver.new(base_url, repos_dir).run
