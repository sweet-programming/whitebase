require 'bcrypt'
require 'securerandom'

module WhiteBase
  class User
    attr_reader :id, :name
    def initialize(id, name)
      @id = id
      @name = name
    end

    def self.config
      @config ||= {}
      yield @config
      @config
    end

    def self.filepath
      path = @config && @config[:filepath]
      path ||= './.passwd'
    end

    def self.register(name, password)
      File.open(filepath, 'w+') do |file|
        file.write([name, SecureRandom.uuid, BCrypt::Password.create(password)].join("\t"))
      end
    end

    def self.auth(username, password)
      File.readlines(filepath).map{|l| l.split("\t")}.select {|name, id, pw|
        username == name && BCrypt::Password.new(pw) == password
      }.map {|name, id, pw| User.new(id, name) }.first
    end
  end
end
