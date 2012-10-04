module Pushare

  module Crypter
    def inbound(t=:client)
      cfg = @cfg[:pushare][:keys]
      raise ":#{t.to_s} not found" if not cfg.has_key? t
      @rsa_dec_key = OpenSSL::PKey::RSA.new(File.read(cfg[t][:sec]),cfg[t][:pas])
    end

    def outbound(t=:server)
      cfg = @cfg[:pushare][:keys]
      raise ":#{t.to_s} not found" if not cfg.has_key? t
      @rsa_enc_key = OpenSSL::PKey::RSA.new(File.read(cfg[t][:pub]))
    end

    def init_crypter(inb=:client,outb=:server)
      raise ':keys not found' if not @cfg[:pushare].has_key? :keys
      inbound(inb)
      outbound(outb)
    end

    def init_cipher(aes="aes-256-cbc",sha2=256)
      @cipher = OpenSSL::Cipher::Cipher.new(aes)
      @cipher.decrypt
      @hasher = Digest::SHA2.new(sha2)
    end

    def decrypt(data)
      @rsa_dec_key.private_decrypt(data)
    end

    def encrypt(data)
      @rsa_enc_key.public_encrypt(data)
    end

    def enciphr(data,chan)
      cfg = @cfg[:pushare][:channels]
      @cipher.encrypt
      @cipher.key = cfg[chan][:key]
      @cipher.iv = cfg[chan][:iv]
      @cipher.update(data) + @cipher.final
    end

    def deciphr(data,chan)
      cfg = @cfg[:pushare][:channels]
      @cipher.decrypt
      @cipher.key = cfg[chan][:key]
      @cipher.iv = cfg[chan][:iv]
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
      log = "data(#{data.to_s.size})"
      redux.inject(data) do |enc,encoder|
        data = send(encoder.to_sym, data, :encode)
        log+=" #{encoder}(#{data.to_s.size})"
      end
      @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] #{log}")
      data
    end

    def decode(redux,data)
      log = " data(#{data.to_s.size})"
      redux.reverse.inject(data) do |enc,encoder|
        data = send(encoder.to_sym, data, :decode)
        log+=" #{encoder}(#{data.to_s.size})"
      end
      @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}]#{log}")
      data
    end

    def enchan(data,_chan,_event)
      chan,event = ffug(_chan,_event)
      @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] event: #{chan}/#{event}")
      enc = encode(@cfg[:pushare][:channels][chan.to_sym][:redux], data)
      enc
    end

    def dechan(data,_chan,_event)
      chan,event  = ffug(_chan,_event)
      @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] event: #{chan}/#{event}")
      dec = decode(@cfg[:pushare][:channels][chan.to_sym][:redux],data)
      dec
    end

    def keygen(chan=:data,len=32)
      @cfg[:pushare][:channels][chan][:iv] = SecureRandom.urlsafe_base64(len)
      @cfg[:pushare][:channels][chan][:key] = SecureRandom.urlsafe_base64(len)
      @cfg[:pushare][:channels][chan][:time] = Time.now.to_i
      {chan=>@cfg[:pushare][:channels][chan]}
    end
  end
end
