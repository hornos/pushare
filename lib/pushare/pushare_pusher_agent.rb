
module Pushare

  module PusherAgent
    def init_pusher
      options = {:secret => @cfg[:pushare][:pusher][:secret]}
      key = @cfg[:pushare][:pusher][:key]
      @socket = PusherClient::Socket.new(key, options)     
    end

    def trigger(chan,event,data,call=nil)
      _chan,_event = guff(chan,event)
      count = @cfg[:pushare][:pusher][:retry][0] || 3
      time = @cfg[:pushare][:pusher][:retry][1] || 5
      begin
        if call.nil?
          data = [@cfg[:pushare][:id],data]
        else
          data = [@cfg[:pushare][:id],data,call]
        end
        Pusher[_chan].trigger(_event, enchan(_chan,_event,data) )
      rescue Exception => ex # error: getaddrinfo:
        sleep time
        count -= 1
        @log.warn("[#{@cfg[:pushare][:id]}/#{__method__}] retry: #{count}")
        retry if count > 0
       end
    end

    def trigger!(chan,event,data)
      trigger(chan,event,data,:data)
    end

    def stop(thread=:control)
      return if @cfg[:pushare][:threads][thread][:thread].nil?
      status = @cfg[:pushare][:threads][thread][:thread].status
      return if status == false
      @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] stop #{thread.to_s} (#{status})")         
      @cfg[:pushare][:threads][:control][:thread].exit
    end

    def options(data)
      data.each do |chan,opts|
        @cfg[:pushare][:channels][chan.to_sym] = Hash[opts.map{ |k, v| [k.to_sym, v] }]
        @cfg[:pushare][:threads][chan.to_sym][:last] = Time.now.to_i
      end
    end

    def start(thread=:data)
      if not @cfg[:pushare][:threads][thread][:thread].nil?
        status = @cfg[:pushare][:threads][thread][:thread].status
        if status == 'sleep'
          @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] resume data thread (#{status})")
          @cfg[:pushare][:threads][thread][:thread].run
        end
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
        # event machine
        loop do
          @log.info("[#{@cfg[:pushare][:id]}/#{__method__}] trigger key")
          trKey
          sleep @cfg[:pushare][:threads][:control][:key_change]
        end

      end
    end


    def data_thread
      @cfg[:pushare][:threads][:data][:thread] = Thread.new do
        last = 0
        # todo event machine
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
            Thread.stop          
          end
        end # data loop
      end # Thread
    end

  end
end
