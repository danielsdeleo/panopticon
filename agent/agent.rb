#!/usr/bin/env ruby
# dirty hack to speed up agent pinging...
ARGV << "--ping-time" << "5" unless ARGV.include?("--ping-time")
load File.dirname(__FILE__) + "/../contrib/nanite/bin/nanite-agent"