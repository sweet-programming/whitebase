class WhiteBase
  def initialize
    @repo = Rugged::Repository.new './repos'
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
