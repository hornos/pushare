module Pushare

  module DataAgent
    def ohai(opts)
      sys = Ohai::System.new
      sys.all_plugins
      ohai = JSON.parse(sys.to_json)
      opts[:exclude].each do |k|
        if m=/(\w+)\/(\w+)/.match(k)
          ohai[m[1]].delete(m[2]) if ohai[m[1]].has_key? m[2]
        end
        ohai.delete(k) if ohai.has_key? k
      end
      ohai
    end
  end
end
