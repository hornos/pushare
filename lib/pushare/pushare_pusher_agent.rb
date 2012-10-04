
module Pushare

  module PusherAgent
    def init_pusher
      options = {:secret => @cfg[:pushare][:pusher][:secret]}
      key = @cfg[:pushare][:pusher][:key]
      @socket = PusherClient::Socket.new(key, options)     
    end

    def trigger(data,chan,event,callb=nil)
      _chan,_event = guff(chan,event)
      raise 'guff error' if _chan.nil? or _event.nil?
      cfg = @cfg[:pushare][:pusher]
      count,time = cfg[:retry][0] || 3, cfg[:retry][1] || 5

      data = [@cfg[:pushare][:id]] << data
      data << callb if not callb.nil?

      # todo: better retry
      begin
        Pusher[_chan].trigger(_event, enchan(data,_chan,_event) )
      rescue Exception => ex
        sleep time
        count -= 1
        @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] #{ex.inspect}")
        @log.warn("[#{@cfg[:pushare][:id]}/#{__method__}] retry: #{count}")
        # binding.pry
        retry if count > 0
       end
    end

    def trigger!(data,chan,event)
      trigger(data,chan,event,:data)
    end

    def stop(thread=:control)
      cfg = @cfg[:pushare][:threads]
      return if cfg[thread][:thread].nil?
      return if cfg[thread][:thread].status == false
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] stop #{thread.to_s}")         
      cfg[:control][:thread].exit
    end

    def options!(data)
      data.each do |chan,opts|
        @cfg[:pushare][:channels][chan.to_sym] = Hash[opts.map{ |k, v| [k.to_sym, v] }]
        @cfg[:pushare][:threads][chan.to_sym][:last] = Time.now.to_i
      end
    end

    def start(thread=:data)
      cfg = @cfg[:pushare][:threads]

      return if cfg[thread][:thread].nil?

      if cfg[thread][:thread].status == 'sleep'
        @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] resume data thread")
        cfg[thread][:thread].run
      end
    end

    def subscribe(chan)
      @socket.subscribe(guff(chan))
    end

    def connect
      begin
        @socket.connect
      rescue Exception => ex
        puts ex.inspect
        # binding.pry
      end

    end

    def control_thread
      @cfg[:pushare][:threads][:control][:thread] = Thread.new do
        delay = @cfg[:pushare][:threads][:control][:delay]
        
        prKey = Proc.new do
          @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger key")
          trKey
          # or
          # keygen(:data)
          # trCfg({:pushare=>{:channels=>{:data=>@cfg[:pushare][:channels][:data].dup}}})
        end

        EventMachine::run do
          EventMachine::schedule(prKey)
          EventMachine::add_periodic_timer(delay, prKey)
        end
      end # Thread
    end


    def config_thread
      @cfg[:pushare][:threads][:control][:thread] = Thread.new do
        delay = @cfg[:pushare][:threads][:control][:delay]
        
        prKey = Proc.new do
          @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger key")
          keygen(:data)
          cfg=[{:pushare=>{:channels=>{:data=>@cfg[:pushare][:channels][:data].dup}}},
           {:pushare=>{:guffs=>@cfg[:pushare][:guffs].dup}}]
          trCfg(cfg)
        end

        EventMachine::run do
          EventMachine::schedule(prKey)
          EventMachine::add_periodic_timer(delay, prKey)
        end
      end # Thread
    end

    def data_thread
      @cfg[:pushare][:threads][:data][:thread] = Thread.new do
        chan = @cfg[:pushare][:channels][:data]
        thread = @cfg[:pushare][:threads][:data]       
        delay = thread[:delay]

        prData = Proc.new do
          if thread[:last].nil? or Time.now.to_i - thread[:last] > thread[:timeout]
            @log.warn("[#{@cfg[:pushare][:id]}/#{__method__}] waiting") 
            # [:iv,:key,:time].each {|k| @cfg[:pushare][:channels][:data].delete(k)}
            Thread.stop
          end

          thread[:trData].each do |task,opts|
            @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] task: #{task.to_s}")
            trData(send(task.to_sym,opts))
          end
        end

        EventMachine::run do
          EventMachine::schedule(prData)
          EventMachine::add_periodic_timer(delay, prData)
        end
        
      end
    end

  end
end
