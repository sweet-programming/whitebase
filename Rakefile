# rakefile

require 'git'
require 'fileutils'

task :init do
  Git.init './repos'
end

task :daily do
  FileUtils.touch File.expand_path('../repos/today.md', __FILE__)
  git = Git.open './repos'
  git.add 'today.md'
end
