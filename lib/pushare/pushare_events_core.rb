module Pushare
  module Events

    # key xc
    def trKey(target=:data,chan=:control,event=:onKey)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] #{chan.to_s}/#{event.to_s} for #{target.to_s}")
      trigger!(chan,event,keygen(target))
    end

    def onKey(_chan,_event,data)
      dec = dechan(_chan,_event,data)
      if dec[0] == @cfg[:pushare][:id]
        @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] self key")
        return
      end

      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] keygen: #{dec[0]}")
        
      stop(:control) # by friendly fire
      options(dec[1]) # for the channel
      # start data channel
      start(dec[2].to_sym) if not dec[2].nil? 
    end

    # data xc
    def trData(data="reductio ad absurdum",chan=:data,event=:onData)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger: #{chan.to_s}/#{event.to_s}")
      trigger(chan,event,data)      
    end

    def onData(_chan,_event,data)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}]")
      begin
        dec = dechan(_chan,_event,data)
        @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] data size: #{dec.to_s.size}")
      rescue Exception => ex
        @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] data error: #{ex.inspect}")        
      end
      # puts dec.inspect
      # send to carbon dec if not @cfg[:pushare][:threads][:data][:onData][:carbon].nil?
    end

    def trExit(data='all',chan=:control,event=:onExit)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger: #{chan.to_s}/#{event.to_s}")
      trigger(chan,event,data)      
    end    

    def onExit(_chan,_event,data)
      dec = dechan(_chan,_event,data)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] exit from: #{dec[0]}")
      # false flag check
      exit(1)
    end

  end # Events
end
