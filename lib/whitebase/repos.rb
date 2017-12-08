require 'date'
require 'pathname'
require 'git'

module WhiteBase
  class Repos
    def self.path=(path)
      @path = Pathname.new(path)
    end

    def self.path
      @path ||= Pathname.new('./repos')
    end

    def initialize
      @git = Git.open(Repos.path)
    end

    def self.open
      Repos.new
    end

    def self.init(path = nil)
      Git.init(path || self.path)
    end

    def commit(time = Time.now)
      @git.add
      @git.commit(time.strftime('%Y-%m-%d %H:%M:%S %z'))
      # options = {}
      # options[:tree] = index.write_tree(@repo)
      # options[:message] = date.strftime('%Y-%m-%d')
      # options[:parents] = @repo.empty? ? [] : [ @repo.head.target ].compact
      # #options[:update_ref] = 'HEAD'
      # Rugged::Commit.create(@repo, options)
    end

    def tag(time = Time.now)
      @git.add_tag(time.strftime('%Y-%m-%d'))
    end

    private
    def start_file_observation
      EM.defer do
        FSSM.monitor("repos", "*") do
          update do|base, file|
            @repo.index.add file
            @repo.commit
          end
          create do|base, file|
            puts "CREATE: #{base} #{file}"
            CometIO.push :filelist, { :type => "add", :filename => file }
          end
          delete do|base, file|
            puts "DELETE: #{base} #{file}"
            CometIO.push :filelist, { :type => "remove", :filename => file }
          end
        end
      end
    end
  end
end
