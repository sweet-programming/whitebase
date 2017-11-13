require 'securerandom'

module WhiteBase
  class Authorization
    def initialize(filepath)
      @filepath = filepath
    end

    def authorize(access_token)
      File.exist?(@filepath) or return nil

      File.readlines(@filepath).each do |line|
        (user_id, token, expire_at) = line.split("\t")
        # TODO take care expire_at
        if access_token == token
          return user_id
        end
      end
      nil
    end

    def login(username, password)
      user = User.auth(username, password) or raise 'login failed'

      access_token = SecureRandom.uuid
      expire_at = Time.now + 3600 * 24 * 7 # 1 week
      File.open(@filepath, 'w+') do |file|
        file.write([user.id, access_token, expire_at].join("\t"))
      end
      access_token
    end

    def revoke(access_token)
      FileUtils.exist?(@filepath) or return

      lines = File.readlines(@filepath)
      lines.reject! do |line|
        (user_id, token, expire_at) = line.split("\t")
        access_token == token
      end
      File.write(@filepath, lines.join)
    end
  end
end
