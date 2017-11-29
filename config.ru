require_relative './server.rb'
require 'thin'
require 'eventmachine'

opts = ARGV.getopts('D', 'port:')

EM.run do
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
