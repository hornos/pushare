module Pushare

  module Crypter
    def inbound(t=:client)
      rsa_dec_key  = @cfg[:pushare][:keys][t][:sec]
      rsa_dec_pas  = @cfg[:pushare][:keys][t][:pas]
      @rsa_dec_key = OpenSSL::PKey::RSA.new(File.read(rsa_dec_key),rsa_dec_pas)
    end

    def outbound(t=:server)
      rsa_enc_key  = @cfg[:pushare][:keys][t][:pub]
      @rsa_enc_key = OpenSSL::PKey::RSA.new(File.read(rsa_enc_key))
    end

    def symmetric(aes="aes-256-cbc",sha2=256)
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
end
