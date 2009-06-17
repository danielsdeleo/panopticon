#!/usr/bin/env ruby
require "pp"
require File.dirname(__FILE__) + "/../contrib/nanite/lib/nanite"
require File.dirname(__FILE__) + "/../lib/panopticon"
include Panopticon

REMOTE_SERVICES = ["diskstats", "memory", "loadavg", "netstats"]

if REMOTE_SERVICES.include?(ARGV[0])
  remote_service = ARGV[0]
else
  if attempted_arg = ARGV[0]
    puts "#{attempted_arg} is not a valid service."
  end
  puts "usage director.rb service"
  puts "available services:"
  REMOTE_SERVICES.each { |service| puts "  " + service }
  exit 1
end

EM.run do
  Nanite.start_mapper
  EM.add_periodic_timer(1) do
    Nanite.request("/panopticon/stats_agent/#{remote_service}", :selector => :all) do |res|
      p res
    end
  end
end