require File.dirname(__FILE__) + "/../../lib/panopticon"

module Panopticon
  class StatsAgent < SystemStats
    include Nanite::Actor
    
    expose :diskstats, :memory, :loadavg, :netstats
    
  end
end