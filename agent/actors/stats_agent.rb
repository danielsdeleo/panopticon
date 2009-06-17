require File.dirname(__FILE__) + "/../../lib/panopticon"

#module Panopticon
  class StatsAgent < Panopticon::SystemStats
    include Nanite::Actor
    
    expose :diskstats, :memory, :loadavg, :netstats
    
  end
#end