require 'net/http'
require 'eventmachine'
require 'fssm'

pid_file = File.expand_path('../.pid', __FILE__)
repos_dir = ENV['REPOS_DIR'] || File.expand_path('../repos', __FILE__)
base_url = ENV['REMOTE_URL']

# Process.daemon
#
# File.write(pid_file, Process.pid)

class FileObserver
  PERIOD = 5

  def initialize(base_url, repos_dir)
    @uri = URI.parse(base_url)
    @repos_dir = repos_dir
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @updated = {}
  end

  def update(file)
    @updated[file] = Time.now
  end

  def tick
    @updated.delete_if do |file, at|
      if at + PERIOD < Time.now
        @http.put("/files/#{file}", File.read(@repos_dir + ?/ + file))
        true
      else
        false
      end
    end
  end

  def run
    EM.run do
      http = @http
      observer = self

      EM.add_periodic_timer(PERIOD) do
        observer.tick
      end

      EM.defer do
        FSSM.monitor(@repos_dir, "*") do
          update do |base, file|
            observer.update(file)
          end

          create do |base, file|
            observer.update(file)
          end

          delete do |base, file|
            puts "DELETE: #{base} #{file}"
          end
        end
      end
    end
  end
end

FileObserver.new(base_url, repos_dir).run
