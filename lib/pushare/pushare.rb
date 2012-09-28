
module Pushare
  module Encoder
    def msgpack(data,enc=:encode)
      return data.to_msgpack          if enc == :encode
      return MessagePack.unpack(data) if enc == :decode
    end

    def xz(data,enc=:encode)
      return XZ::compress(data)   if enc == :encode
      return XZ::decompress(data) if enc == :decode
    end

    def rsa(data,enc=:encode)
      return encrypt(data) if enc == :encode
      return decrypt(data) if enc == :decode
    end

    def aes(data,enc=:encode,chan=:data)
      return enciphr(data,chan) if enc == :encode
      return deciphr(data,chan) if enc == :decode
    end

    def ascii85(data,enc=:encode)
      return Ascii85.encode(data) if enc == :encode
      return Ascii85.decode(data) if enc == :decode
    end
  end

  module Crypter
    def decrypt(data)
      @rsa_dec_key.private_decrypt(data)
    end

    def encrypt(data)
      @rsa_enc_key.public_encrypt(data)
    end

    def enciphr(data,chan)
      @cipher.encrypt
      @cipher.key = @cfg[:pushare][:channels][chan][:key]
      @cipher.iv = @cfg[:pushare][:channels][chan][:iv]
      @cipher.update(data) + @cipher.final
    end

    def deciphr(data,chan)
      @cipher.decrypt
      @cipher.key = @cfg[:pushare][:channels][chan][:key]
      @cipher.iv = @cfg[:pushare][:channels][chan][:iv]
      @cipher.update(data) + @cipher.final
    end

    # human to guff readable
    def guff(*data)
      data.map { |d| @cfg[:pushare][:guffs][d] }
    end
    # guff to human readable
    def ffug(*data)
      data.map { |d| @cfg[:pushare][:guffs].rassoc(d)[0] }
    end

    def encode(redux,data)
      redux.inject(data) do |enc,encoder|
        data = send(encoder.to_sym, data, :encode)
        @log.debug("[#{__method__}] #{encoder}")
      end
      data
    end

    def decode(redux,data)
      redux.reverse.inject(data) do |enc,encoder|
        data = send(encoder.to_sym, data, :decode)
        @log.debug("[#{__method__}] #{encoder} (#{data.size})")
      end
      data
    end

    def enchan(_chan,_event,data)
      chan,event = ffug(_chan,_event)
      enc = encode(@cfg[:pushare][:channels][chan.to_sym][:redux], data)
      @log.debug("[#{__method__}] #{chan}(#{_chan})/#{event}(#{_event})")
      @log.debug("[#{__method__}] data: #{data}")
      # @log.debug("[#{__method__}] enc : #{enc}")
      @log.debug("[#{__method__}] size: #{data.size}(#{enc.size})")
      enc
    end

    def dechan(_chan,_event,data)
      chan,event  = ffug(_chan,_event)
      dec = decode(@cfg[:pushare][:channels][chan.to_sym][:redux],data)
      @log.debug("[#{__method__}] #{chan}(#{_chan})/#{event}(#{_event})")
      # @log.debug("[#{__method__}] data: #{data}")
      @log.debug("[#{__method__}] dec : #{dec}")
      @log.debug("[#{__method__}] size: #{data.size}(#{dec.size})")
      dec
    end

    def keygen(chan=:data,len=32)
      @cfg[:pushare][:channels][chan][:iv] = SecureRandom.urlsafe_base64(len)
      @cfg[:pushare][:channels][chan][:key] = SecureRandom.urlsafe_base64(len)
      @cfg[:pushare][:channels][chan][:time] = Time.now.to_i
      {chan=>@cfg[:pushare][:channels][chan]}
    end
  end

  module PusherAgent
    def socketalize
      options = {:secret => @cfg[:pushare][:pusher][:secret]}
      key = @cfg[:pushare][:pusher][:key]
      @socket = PusherClient::Socket.new(key, options)     
    end

    def trigger(chan,event,data)
      _chan,_event = guff(chan,event)
      Pusher[_chan].trigger(_event, enchan(_chan,_event,data) )
    end

    def trKey(target=:data,chan=:control)
      trigger(chan,:onKey,keygen(target))
    end

    def onKey(_chan,_event,data)
      dec = dechan(_chan,_event,data)
      dec.each do |chan,opts|
        @cfg[:pushare][:channels][chan.to_sym] = Hash[opts.map{ |k, v| [k.to_sym, v] }]
        @cfg[:pushare][:threads][chan.to_sym][:last] = Time.now.to_i
      end
    end

    def trData(data="reductio ad absurdum",chan=:data)
      trigger(chan,:onData,data)      
    end

    def onData(_chan,_event,data)
      dec = dechan(_chan,_event,data)
      @log.debug("[#{__method__}] data: #{dec}")
    end


    def subscribe(chan)
      @socket.subscribe(guff(chan))
    end

    def connect
      @socket.connect
    end

    # TODO eventmachine thread
    def data_loop
      @cfg[:pushare][:threads][:data][:thread] = Thread.new do
        last = 0

        loop do
          chan = @cfg[:pushare][:channels][:data]
          thread = @cfg[:pushare][:threads][:data]
          if chan.has_key? :iv
            data_send = thread[:data_send]
            last = thread[:last]
            
            delay = Time.now.to_i - last
            if delay > thred[:delay]
              [:iv,:key,:time].each {|k| @cfg[:pushare][:channels][:data].delete(k)}
              @log.debug("[#{__method__}] timeout")             
            else

              thread[:trData].each do |task,opts|
               trData(send(task.to_sym,opts))
              end

              @log.debug("[#{__method__}] trigger data (#{data_send}/#{delay})")
              sleep data_send
            end           
          else
            key_check = @cfg[:pushare][:threads][:data][:key_check]
            @log.debug("[#{__method__}] no key (#{key_check})")
            sleep key_check           
          end
        end # data loop
      end # Thread
    end

  end

  module DataAgent
    def ohai(opts)
      sys = Ohai::System.new
      sys.all_plugins
      ohai = JSON.parse(sys.to_json)
      opts[:exclude].each do |k|
        if m=/(\w+)\/(\w+)/.match(k)
          ohai[m[1]].delete(m[2]) if ohai[m[1]].has_key? m[2]
        end
        ohai.delete(k) if ohai.has_key? k
      end
      ohai
    end
  end


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
      rsa_dec_key  = @cfg[:pushare][:keys][:client][:sec]
      rsa_dec_pas  = @cfg[:pushare][:keys][:client][:pas]
      @rsa_dec_key = OpenSSL::PKey::RSA.new(File.read(rsa_dec_key),rsa_dec_pas)

      # outbound: client -> server
      rsa_enc_key  = @cfg[:pushare][:keys][:server][:pub]
      @rsa_enc_key = OpenSSL::PKey::RSA.new(File.read(rsa_enc_key))

      @cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      @cipher.decrypt

      @hasher = Digest::SHA2.new(256)

      # pusher
      socketalize

    end
  end
  
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
      rsa_dec_key  = @cfg[:pushare][:keys][:server][:sec]
      rsa_dec_pas  = @cfg[:pushare][:keys][:server][:pas]
      @rsa_dec_key = OpenSSL::PKey::RSA.new(File.read(rsa_dec_key),rsa_dec_pas)

      # outbound: server -> client
      rsa_enc_key  = @cfg[:pushare][:keys][:client][:pub]
      @rsa_enc_key = OpenSSL::PKey::RSA.new(File.read(rsa_enc_key))

      @cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      @cipher.encrypt

      @hasher = Digest::SHA2.new(256)

      # pusher
      socketalize

    end
  end 
end # Pushare

