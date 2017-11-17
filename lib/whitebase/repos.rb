require 'date'
require 'pathname'
require 'git'

module WhiteBase
  class Repos
    def initialize(dir = nil)
      @dir = dir || Pathname.new(__dir__) + 'repos'
      @git = Git.open(@dir)
    end

    def self.init(dir = nil)
      dir = dir || Pathname.new(__dir__) + 'repos'
      Git.init(dir)
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
