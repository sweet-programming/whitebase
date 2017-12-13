require 'date'
require 'set'
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
    end

    def tag
      tagged = Set.new(@git.tags.map(&:name))
      @git.log.each do |log|
        begin
          date = Time.parse(log.messge).strftime('%Y-%m-%d')
          unless tagged.include?(date)
            @git.add_tag(date)
            tagged.add(date)
          end
        rescue
        end
      end
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
