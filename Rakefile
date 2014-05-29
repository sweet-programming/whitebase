# rakefile

require 'rugged'

task :init do
  Rugged::Repository.init_at './repos'
end

task :daily do
  repo = Rugged::Repository.new './repos'
  repo.index.add 'today.md'
end
