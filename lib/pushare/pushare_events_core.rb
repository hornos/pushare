class Hash
  # http://grosser.it/2009/04/14/recursive-symbolize_keys/
  def recursive_symbolize_keys!
    symbolize_keys!
    values.select { |v| v.is_a?(Hash) }.each { |h| h.recursive_symbolize_keys! }
  end

  # http://apidock.com/rails/Hash/symbolize_keys%21
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  # http://rails.rubyonrails.org/classes/ActiveSupport/CoreExtensions/Hash/DeepMerge.html
  def deep_merge(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
    end
  end
  def deep_merge!(other_hash)
    replace(deep_merge(other_hash))
  end

end

module Pushare
  module Events

    # key xc
    def trKey(data=:data,chan=:control,event=:onKey)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] #{chan.to_s}/#{event.to_s} for #{data.to_s}")
      trigger(keygen!(data),chan,event)
    end

    def trKey!(chan=:control,event=:onKey)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] #{chan.to_s}/#{event.to_s} for #{data.to_s}")
      trigger!(keygen!(data),chan,event,:data)
    end

    def onKey(data,_chan,_event)
      src,opts,dst = dechan(data,_chan,_event)
      if src == @cfg[:pushare][:id]
        @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] self key")
        return
      end

      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] keygen: #{src}")
        
      stop(:control) # by friendly fire
      options!(opts) # for the channel
      # start traget channel
      start(dst.to_sym) if not dst.nil? 
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

    def trCfg(data,chan=:data,event=:onCfg)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] for #{chan.to_s}/#{event.to_s}")
      trigger(data,chan,event)      
    end

    def onCfg(data,_chan,_event)
      dec = dechan(data,_chan,_event)

      @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] #{dec.inspect}")
      return if dec.shift == @cfg[:pushare][:id]

      dec.each do |d|
        d.recursive_symbolize_keys!
        if d.has_key? :pushare
          @cfg.deep_merge!(d)
          @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] #{d.to_s}")
        end
      end

      start(:data) # threads/data/thread
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
