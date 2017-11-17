# rakefile

require 'git'
require 'fileutils'
require_relative 'lib/whitebase/repos'

task :init do
  WhiteBase::Repos.init
end

task :daily do
  FileUtils.touch File.expand_path('../repos/today.md', __FILE__)
  git = Git.open './repos'
  git.add 'today.md'
end
