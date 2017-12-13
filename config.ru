require_relative './server.rb'
require 'thin'
require 'eventmachine'

opts = ARGV.getopts('D', 'port:')
repos = ARGV.getopts('r', 'repos') || 'repos'

EM.run do
  last_tagged_at = Time.now

  EM.add_periodic_timer(5 * 60) do
    now = Time.now
    if now.to_date > last_tagged_at.to_date
      WhiteBase::Repos.open.tag
      last_tagged_at = now
    end
  end

  app = Rack::Builder.app do
    map '/' do
      run WhiteBase::Server.new
    end
  end

  Rack::Server.start({
    app:    app,
    server: 'thin',
    Port:   opts['port'] || 9292,
    daemon: opts['D'],
    signals: false
  })
end
