module Panopticon
  class SystemStats
    attr_reader :system, :os
    
    def initialize
      @system = Ohai::System.new
      @system.require_plugin("os")
      @os = @system.data["os"]
    end
    
    def memory(args=nil)
      @system.require_plugin("#{os}/memory", true)
      @system.data["memory"]
    end
    
    # Uses the raw counter stats from #raw_diskstats to compute per second
    # disk I/O stats
    # It is assumed that sectors are always and everywhere 512 bytes.
    def diskstats(args=nil)
      if @last_raw_diskstats
        current_raw_stats = raw_diskstats
        diskstats_per_s = compute_diskstats_per_s(current_raw_stats, @last_raw_diskstats)
        @last_raw_diskstats = current_raw_stats
        diskstats_per_s
      else
        @last_raw_diskstats = raw_diskstats
        nil
      end
    end
    
    # Reads disk stats from /proc/diskstats. 2.4 kernels don't have this, instead the
    # info is in /proc/partitions. 2.4 /proc/partition example:
    #   3     0   39082680 hda 446216 784926 9550688 4382310 424847 312726 5922052 19310380 0 3376340 23705160
    # 2.6 /proc/diskstats example:
    #   8       5 sda5 555 40207 43622 1210 3 1 5 0 0 620 1210
    def raw_diskstats
      if @os == "linux"
        iostats = {"time" => Time.now.to_f}
        File.open("/proc/diskstats", "r").each do |line|
          fields = line.chomp.split
          if fields[2] =~ /(sda|hda|dm\-)/
            iostats[fields[2]] = {"reads"=> fields[3].to_i, "sectors_read" => fields[5].to_i, "writes" => fields[7].to_i, "sectors_written" => fields[9].to_i}
          end
        end
        iostats
      end
    end
      
    def loadavg(args=nil)
      load_stats = {"time" => Time.now.to_f}
      if @os == "linux"
        File.open("/proc/loadavg", "r").each do |line|
          next if line =~ /^[\s]*$/
          fields = line.split
          load_stats["1"] = fields[0]
          load_stats["5"] = fields[1]
          load_stats["10"] = fields[2]
          load_stats["processes"] = fields[3].split("/").last
        end
      end
      load_stats
    end
    
    def raw_netstats
      net_stats = {"time" => Time.now.to_f}
      if @os == "linux"
        File.open("/proc/net/dev", "r").each do |line|
          next if line =~ /(inter|face|receive|transmit|bytes)/i
          fields = line.split
          iface = fields[0].gsub(":", "")
          net_stats[iface] = {"receive_bytes"=>fields[1].to_i, "receive_packets"=>fields[2].to_i, "sent_bytes"=>fields[9].to_i, "sent_packets"=>fields[10].to_i}
        end
      end
      net_stats
    end
    
    def netstats(args=nil)
      if @last_raw_netstats
        current_raw_stats = raw_netstats
        netstats_per_s = compute_netstats_per_s(current_raw_stats, @last_raw_netstats)
        @last_raw_netstats = current_raw_stats
        netstats_per_s
      else
        @last_raw_netstats = raw_netstats
        nil
      end
    end
    
    def compute_netstats_per_s(newer_raw_stats, older_raw_stats)
      netstats_hsh = {}
      time_delta = newer_raw_stats["time"] - older_raw_stats["time"]
      newer_raw_stats.each do |key, current_disk_counters|
        unless key == "time"
          netstats_hsh[key] = net_io_per_s(current_disk_counters, older_raw_stats[key], time_delta)
        end
      end
      netstats_hsh
    end
    
    def compute_diskstats_per_s(newer_raw_stats, older_raw_stats)
      diskstats_hsh = {}
      time_delta = newer_raw_stats["time"] - older_raw_stats["time"]
      newer_raw_stats.each do |key, current_disk_counters|
        unless key == "time"
          diskstats_hsh[key] = disk_io_per_s(current_disk_counters, older_raw_stats[key], time_delta)
        end
      end
      diskstats_hsh
    end
    
    def net_io_per_s(newer_counter_vals, older_counter_vals, time_delta)
      # in: {"receive_bytes"=>0, "receive_packets"=>0, "sent_bytes"=>0, "sent_packets"=>0}
      # out: {"receive_bytes/s"=>0, "receive_packets/s"=>0, "sent_bytes/s"=>0, "sent_packets/s"=>0}
      net_io_hsh = {}
      newer_counter_vals.each do |key, counter_value|
        net_io_hsh[key + "/s"] = subtract_counters(counter_value, older_counter_vals[key]) / time_delta.to_f
      end
      net_io_hsh
    end
    
    def disk_io_per_s(newer_counter_vals, older_counter_vals, time_delta)
      io_stats_hsh ={}
      {"sectors_read"=>"bytes_read/s", "sectors_written"=>"bytes_written/s"}.each do |key,new_key|
        io_stats_hsh[new_key] = (subtract_counters(newer_counter_vals[key], older_counter_vals[key]) * 512) / time_delta.to_f
      end
      {"reads"=>"reads/s", "writes"=>"writes/s"}.each do |key,new_key|
        io_stats_hsh[new_key] = subtract_counters(newer_counter_vals[key], older_counter_vals[key]) / time_delta.to_f
      end
      io_stats_hsh
    end
    
    # Subtracts 32 bit unsigned int counters, handling the case that the 
    # counter has wrapped around the max.
    # BUG/FAIL: these counters apparently wrap at the word length of the CPU
    # arch, i.e. 32 bit or 64 bit. of 2^32 -1 => 4294967295
    def subtract_counters(newer_counter, older_counter)
      if older_counter <= newer_counter
        newer_counter - older_counter
      else
        (uint_max_size - older_counter) + newer_counter
      end
    end
    
    def uint_max_size
      @uint_max_size ||= (uname_m =~ /(ia64|x86_64)/ ? ((2**64) - 1) : ((2 ** 32) - 1))
    end
    
    def uname_m
      `uname -m`
    end
    
  end
end