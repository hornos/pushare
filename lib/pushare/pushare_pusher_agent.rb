
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
        @log.debug(ex.inspect)
        sleep time
        count -= 1
        @log.debug("[#{__method__}] retry: #{count}")
        retry if count > 0
        # binding.pry
      end
    end

    def trKey(target=:data,chan=:control)
      trigger(chan,:onKey,keygen(target))
    end

    def onKey(_chan,_event,data)
      dec = dechan(_chan,_event,data)
      @log.debug("[#{__method__}] keychange from #{dec[0]}")     
      dec[1].each do |chan,opts|
        @cfg[:pushare][:channels][chan.to_sym] = Hash[opts.map{ |k, v| [k.to_sym, v] }]
        @cfg[:pushare][:threads][chan.to_sym][:last] = Time.now.to_i
      end
    end

    def onKey2(_chan,_event,data)
      @log.debug("#{__method__} #{_chan} #{_event}")
      #dec = dechan(_chan,_event,data)
      #@log.debug("[#{__method__}] keychange from #{dec.inspect}")     
      # dec[1].each do |chan,opts|
      #  @cfg[:pushare][:channels][chan.to_sym] = Hash[opts.map{ |k, v| [k.to_sym, v] }]
      #  @cfg[:pushare][:threads][chan.to_sym][:last] = Time.now.to_i
      # end
    end

    def trData(data="reductio ad absurdum",chan=:data)
      trigger(chan,:onData,data)      
    end

    def onData(_chan,_event,data)
      begin
        dec = dechan(_chan,_event,data)
        @log.debug("[#{__method__}] data: #{dec}")
      rescue Exception => ex
        @log.debug("[#{__method__}] data error: #{ex.inspect}")        
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

    def key_loop
      @cfg[:pushare][:threads][:control][:thread] = Thread.new do

        loop do
          trKey
          @log.debug("[#{__method__}] trigger key")
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
end
