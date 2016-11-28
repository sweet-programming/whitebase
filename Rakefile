# rakefile

require 'git'

task :init do
  Git.init './repos'
end

task :daily do
  git = Git.new './repos'
  git.add 'today.md'
end
