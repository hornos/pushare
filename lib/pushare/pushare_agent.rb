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

      Pusher.app_id = @cfg[:pushare][:pusher][:app_id]
      Pusher.key = @cfg[:pushare][:pusher][:key]
      Pusher.secret = @cfg[:pushare][:pusher][:secret]
      Pusher.encrypted = true
      PusherClient.logger = Logger.new(STDOUT)
      PusherClient.logger.level = Logger::WARN

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

      puts @cfg.to_yaml
    end

    def bind(chan,event)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] #{chan}/#{event}")
      chan,event = guff(chan,event)
      socket[chan].bind(event) do |data|
        yield(data,chan,event)
      end if block_given?
    end

  end # Agent

  class Client < Agent
    def initialize(cfg)
      super(cfg,:client,:server)
    end

    def run
      data_thread
      connect
    end
  end

  class Server < Agent
    def initialize(cfg)
      super(cfg,:server,:client)
    end

    def client_thread
      Thread.new do
        client = Client.new(@cfg)

        client.bind(:control,:onKey) do |data,chan,event|
          client.onKey(data,chan,event)
        end

        client.connect
      end
    end

    def run
      client_thread
      control_thread
      connect
    end
  end

end
