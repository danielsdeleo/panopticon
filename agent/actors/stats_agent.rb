module Panopticon
  class StatsAgent < SystemStats
    include Nanite::Actor
    
    expose :diskstats, :memory, :loadavg, :netstats
    
  end
end