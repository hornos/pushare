module Pushare

  class Client
    include Crypter
    include Encoder
    include PusherAgent
    include DataAgent

    attr_accessor :socket
    attr_accessor :cfg
    attr_accessor :log

    def initialize(cfg)
      @log = Logger.new(STDOUT)
      @cfg = cfg

      # inbound: server -> client
      inbound(:client)

      # outbound: client -> server
      outbound(:server)

      symmetric

      # pusher
      socketalize

    end
  end

end

