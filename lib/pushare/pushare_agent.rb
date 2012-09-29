module Pushare

  class Agent
    include Crypter
    include Encoder
    include PusherAgent
    include DataAgent

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
      inbound(inb)
      outbound(outb)

      # init aes
      symmetric

      # init pusher
      socketalize

    end
  end 
end
