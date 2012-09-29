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
end
