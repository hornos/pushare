module Pushare
  
  class Server
    include Crypter
    include Encoder
    include PusherAgent

    attr_accessor :socket
    attr_accessor :cfg
    attr_accessor :log

    def initialize(cfg)
      @cfg = cfg
      @log = Logger.new(STDOUT)
 
      # inbound: client -> server
      inbound(:server)

      # outbound: server -> client
      outbound(:client)

      symmetric

      # pusher
      socketalize

    end
  end 
end