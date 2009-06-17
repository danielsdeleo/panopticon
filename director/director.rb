#!/usr/bin/env ruby
require "pp"
require File.dirname(__FILE__) + "/../contrib/nanite/lib/nanite"
require File.dirname(__FILE__) + "/../lib/panopticon"
module Panopticon
  class Director
    REMOTE_SERVICES = ["diskstats", "memory", "loadavg", "netstats"]
    
    def initialize(argv)
      @statistics_type = argv[0]
    end
    
    def run
      EM.run do
        Nanite.start_mapper
        EM.add_periodic_timer(1) do
          nanite_actor_service = "/stats_agent/#{@statistics_type}"
          p "requesting actor service #{nanite_actor_service}"
          Nanite.request(nanite_actor_service,nil, :selector => :all) do |res|
            p res
          end
        end
      end
    end
    
    private
    
    def validate_command
      usage unless @statistics_type
      invalid_service unless REMOTE_SERVICES.include?(@statistics_type)
    end
    
    def invalid_service
      puts "The requested server stats type ``#{attempted_arg}'' is not valid."
      usage
    end
    
    def usage
      puts "usage director.rb service"
      puts "available statistics:"
      REMOTE_SERVICES.each { |service| puts "  " + service }
      exit 1
    end
    
  end
end

director = Panopticon::Director.new(ARGV)
director.run