require 'logger'
require 'fileutils'

module WhiteBase
  class AppLogger
    APP_NAME = 'WhiteBase'

    attr_accessor :path
    attr_accessor :logger

    def self.init
      @instance = self.new
      yield @instance if block_given?

      @instance.path ||= 'logs/whitebase_app.log'
      FileUtils.touch @instance.path
      @instance.logger = Logger.new(@instance.path)
    end

    def with_error_log(ignore_raise = false)
      begin
        yield
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
        self.exception(e)
        raise unless ignore_raise
      end
    end

    def self.with_error_log(ignore_raise = false, &block)
      @instance.with_error_log(ignore_raise, &block)
    end

    def info(mesg)
      @logger.info("#{APP_NAME}: #{mesg}")
    end

    def self.info(mesg)
      @instance.info(mesg)
    end

    def debug(mesg)
      @logger.debug("#{APP_NAME}: #{mesg}")
    end

    def self.debug(mesg)
      @instance.debug(mesg)
    end

    def warn(mesg)
      @logger.warn("#{APP_NAME}: #{mesg}")
    end

    def self.warn(mesg)
      @instance.warn(mesg)
    end

    def error(mesg)
      @logger.error("#{APP_NAME}: #{mesg}")
    end

    def self.error(mesg)
      @instance.error(mesg)
    end

    def exception(e, bt = true)
      error(e.message)
      @logger.error(e.backtrace.join("\n")) if bt
    end

    def self.exception(e, bt = true)
      @instance.exception(e, bt)
    end
  end
end
