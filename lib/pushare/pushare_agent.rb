module Pushare

  class Agent
    include Crypter
    include Encoder
    include PusherAgent
    include DataAgent
    include Events

    attr_accessor :socket
    attr_accessor :cfg
    attr_accessor :log

    def initialize(cfg,inb=:client,outb=:server)
      @cfg = cfg
      @log = Logger.new(STDOUT)
      @log.formatter = proc do |severity, datetime, progname, msg|
        "#{severity} #{datetime}: #{msg}\n"
      end
 
      # init rsa
      init_crypter(inb,outb)

      # init aes
      init_cipher

      # init pusher
      init_pusher

    end
  end 
end
