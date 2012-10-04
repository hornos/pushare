class Hash
  def recursive_symbolize_keys!
    symbolize_keys!
    values.select { |v| v.is_a?(Hash) }.each { |h| h.recursive_symbolize_keys! }
  end
end

module Pushare
  module Events

    # key xc
    def trKey(data=:data,chan=:control,event=:onKey)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] #{chan.to_s}/#{event.to_s} for #{data.to_s}")
      trigger(keygen(data),chan,event)
    end

    def trKey!(chan=:control,event=:onKey)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] #{chan.to_s}/#{event.to_s} for #{data.to_s}")
      trigger!(keygen(data),chan,event,:data)
    end

    def onKey(data,_chan,_event)
      dec = dechan(data,_chan,_event)
      if dec[0] == @cfg[:pushare][:id]
        @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] self key")
        return
      end

      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] keygen: #{dec[0]}")
        
      stop(:control) # by friendly fire
      options!(dec[1]) # for the channel
      # start data channel
      start(dec[2].to_sym) if not dec[2].nil? 
    end

    # data xc
    def trData(data=Time.now.to_s,chan=:data,event=:onData)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger: #{chan.to_s}/#{event.to_s}")
      trigger(data,chan,event)      
    end

    def onData(data,_chan,_event)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}]")
      begin
        dec = dechan(data,_chan,_event)
        @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] data size: #{dec.to_s.size}")
      rescue Exception => ex
        @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] data error: #{ex.inspect}")        
      end
    end

    def trCfg(data,chan=:control,event=:onCfg)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] for #{chan.to_s}/#{event.to_s}")
      trigger(data,chan,event)      
    end

    def onCfg(data,_chan,_event)
      dec = dechan(data,_chan,_event)

      return if dec.shift == @cfg[:pushare][:id]
      # @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] self cfg")

      dec.each do |cfg|
        cfg.recursive_symbolize_keys!
        if cfg.has_key? :pushare
          @cfg.merge!(cfg)
          @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] #{cfg.to_s}")
        end
      end

      start(:data)
    end

    # exit
    def trExit(data=/.*/,chan=:control,event=:onExit)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger: #{chan.to_s}/#{event.to_s}")
      trigger(data,chan,event)      
    end    

    def onExit(data,_chan,_event)
      dec = dechan(data,_chan,_event)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] exit from: #{dec[0]}")
      exit(1)
    end

  end # Events
end
