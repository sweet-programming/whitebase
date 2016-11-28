require 'date'
require 'pathname'
require 'git'

class WhiteBase
  def initialize
    @git = Git.open(Pathname.new(__dir__) + 'repos')
  end

  def commit(date = Date.today)
    @git.add
    @git.commit(date.strftime('%Y-%m-%d'))
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
