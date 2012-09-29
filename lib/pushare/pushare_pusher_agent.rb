
module Pushare

  module PusherAgent
    def socketalize
      options = {:secret => @cfg[:pushare][:pusher][:secret]}
      key = @cfg[:pushare][:pusher][:key]
      @socket = PusherClient::Socket.new(key, options)     
    end

    # inverse long poll
    def trigger(chan,event,data)
      _chan,_event = guff(chan,event)
      count = @cfg[:pushare][:pusher][:trigger][:count] || 3
      time = @cfg[:pushare][:pusher][:trigger][:sleep] || 5
      begin
        Pusher[_chan].trigger(_event, enchan(_chan,_event,[@cfg[:pushare][:id],data]) )
      rescue SocketError => ex
        sleep time
        count -= 1
        @log.warn("[#{@cfg[:pushare][:id]}/#{__method__}] retry: #{count}")
        retry if count > 0
        # binding.pry
      end
    end

    # Key event
    def trKey(target=:data,chan=:control,event=:onKey)
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger: #{chan.to_s}/#{event.to_s} #{target.to_s}")
      trigger(chan,event,keygen(target))
    end

    def onKey(_chan,_event,data)
      dec = dechan(_chan,_event,data)
      if dec[0] == @cfg[:pushare][:id]
        @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] self key")
      else
        @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] new key from: #{dec[0]}")
        # friendly fire
        if not @cfg[:pushare][:threads][:control][:thread].nil?
          status = @cfg[:pushare][:threads][:control][:thread].status
          if not status == false
            @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] stop trigger key (#{status})")         
            @cfg[:pushare][:threads][:control][:thread].exit
          end
        end
        dec[1].each do |chan,opts|
          @cfg[:pushare][:channels][chan.to_sym] = Hash[opts.map{ |k, v| [k.to_sym, v] }]
          @cfg[:pushare][:threads][chan.to_sym][:last] = Time.now.to_i
        end
      end 
    end

    # Data event
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

    def stop
      @cfg[:pushare][:threads][:control][:thread].kill if not @cfg[:pushare][:threads][:control][:thread].nil?
      @cfg[:pushare][:threads][:data][:thread].kill if not @cfg[:pushare][:threads][:data][:thread].nil?
      exit(0)   
    end

    def control_loop
      @cfg[:pushare][:threads][:control][:thread] = Thread.new do

        loop do
          @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger key")
          trKey
          sleep @cfg[:pushare][:threads][:control][:key_change]
        end
      end
    end


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
            if delay > thread[:delay]
              @log.warn("[#{@cfg[:pushare][:id]}/#{__method__}] timeout") 
              [:iv,:key,:time].each {|k| @cfg[:pushare][:channels][:data].delete(k)}             
            else

              # send data
              thread[:trData].each do |task,opts|
                @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] task: #{task.to_s}")
                trData(send(task.to_sym,opts))
              end
              sleep data_send
            end           
          else
            @log.debug("[#{@cfg[:pushare][:id]}/#{__method__}] waiting")
            key_check = @cfg[:pushare][:threads][:data][:key_check]
            sleep key_check           
          end
        end # data loop
      end # Thread
    end

  end
end
