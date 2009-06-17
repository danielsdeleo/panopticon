require File.dirname(__FILE__) + '/../spec_helper'

describe SystemStats do
    SAMPLE_DISKSTATS=<<-EOF
      1       0 ram0 0 0 0 0 0 0 0 0 0 0 0
      1       1 ram1 0 0 0 0 0 0 0 0 0 0 0
      1       2 ram2 0 0 0 0 0 0 0 0 0 0 0
      1       3 ram3 0 0 0 0 0 0 0 0 0 0 0
      1       4 ram4 0 0 0 0 0 0 0 0 0 0 0
      1       5 ram5 0 0 0 0 0 0 0 0 0 0 0
      1       6 ram6 0 0 0 0 0 0 0 0 0 0 0
      1       7 ram7 0 0 0 0 0 0 0 0 0 0 0
      1       8 ram8 0 0 0 0 0 0 0 0 0 0 0
      1       9 ram9 0 0 0 0 0 0 0 0 0 0 0
      1      10 ram10 0 0 0 0 0 0 0 0 0 0 0
      1      11 ram11 0 0 0 0 0 0 0 0 0 0 0
      1      12 ram12 0 0 0 0 0 0 0 0 0 0 0
      1      13 ram13 0 0 0 0 0 0 0 0 0 0 0
      1      14 ram14 0 0 0 0 0 0 0 0 0 0 0
      1      15 ram15 0 0 0 0 0 0 0 0 0 0 0
     11       0 sr0 4 57 488 100 0 0 0 0 0 100 100
      8       0 sda 3869 56530 279690 19560 3337 2120 43645 309610 0 19060 329170
      8       1 sda1 3291 16300 235712 18330 3334 2119 43640 309610 0 18470 327940
      8       2 sda2 2 0 4 0 0 0 0 0 0 0 0
      8       5 sda5 555 40207 43622 1210 3 1 5 0 0 620 1210
    252       0 dm-0 18928 0 232810 42880 5455 0 43640 481370 0 18450 524250
    252       1 dm-1 215 0 1720 0 0 0 0 0 0 0 0
  EOF

  SAMPLE_LOADAVG="0.11 0.55 0.10 2/185 4790\n"
  
  SAMPLE_NETDEV=<<-NETDEV
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo:       0       0    0    0    0     0          0         0        0       0    0    0    0     0       0          0
  eth0:   72933     810  809    0    0     0          0         0    67226     454    0    0    0     0       0          0
NETDEV
  
  before(:each) do
    @sys_stats = SystemStats.new
    @sys_stats.stub!(:uint_max_size).and_return((2**32) - 1)
    force_linux_os
  end
  
  def force_linux_os
    @sys_stats.instance_variable_set(:@os, "linux")
  end
  
  it "should detect the OS type" do
    RUBY_PLATFORM.should match Regexp.new(SystemStats.new.os)
  end
  
  it "should rescue when trying to get stats on an unsupported platform" do
    @sys_stats.instance_variable_set(:@os, "darwin")
    lambda {@sys_stats.memory}.should_not raise_error
  end
  
  it "should get memory stats for supported platforms" do
    sample_mem_stats = {"dirty"=>"0kB", "vmalloc_used"=>"2344kB", "page_tables"=>"908kB", "buffers"=>"82348kB", "slab_unreclaim"=>"4768kB", "high_free"=>"0kB", "vmalloc_chunk"=>"763836kB", "nfs_unstable"=>"0kB", "slab"=>"9940kB", "inactive"=>"52484kB", "total"=>"250692kB", "vmalloc_total"=>"770040kB", "low_free"=>"75272kB", "low_total"=>"250692kB", "free"=>"75272kB", "commit_limit"=>"854424kB", "anon_pages"=>"19548kB", "writeback"=>"0kB", "cached"=>"55684kB", "swap"=>{"total"=>"729080kB", "free"=>"729080kB", "cached"=>"0kB"}, "high_total"=>"0kB", "committed_as"=>"493196kB", "bounce"=>"0kB", "slab_reclaimable"=>"5172kB", "mapped"=>"7876kB", "active"=>"105096kB"}
    @sys_stats.system.expects(:require_plugin).with("#{@sys_stats.os}/memory", true).returns(true)
    @sys_stats.system.expects(:data).returns({"kernel"=>"whatev", "memory"=> sample_mem_stats})
    @sys_stats.memory.should == sample_mem_stats
  end
  
  it "should get raw disk I/O stats for supported platforms" do
    File.expects(:open).with("/proc/diskstats", "r").returns(SAMPLE_DISKSTATS.split("\n"))
    diskstats = @sys_stats.raw_diskstats
    diskstats.should_not be_nil
    ["sda", "sda1", "sda2", "sda5", "dm-0", "dm-1"].each do |expected_key|
      diskstats.should have_key expected_key
    end
    diskstats["dm-0"].should == {"reads"=>18928, "writes"=>5455, "sectors_written"=>43640, "sectors_read"=>232810}
  end
  
  it "should give 32 bit integer as max UINT size for non-(ia64, x86_64) platforms" do
    sys_stats = SystemStats.new
    sys_stats.expects(:uname_m).returns("i686")
    sys_stats.uint_max_size.should == ((2**32) - 1)
  end
  
  it "should give 64 bit integer as max UINT size for ia64||x86_64" do
    sys_stats = SystemStats.new
    sys_stats.expects(:uname_m).returns("x86_64")
    sys_stats.uint_max_size.should == ((2**64) - 1)
  end
  
  it "should subtact counter values when values don't wrap around max unsigned int size" do
    @sys_stats.subtract_counters(2300, 1800).should == 500
  end
  
  it "should subtract counter values when values wrap around max unsigned int size" do
    @sys_stats.subtract_counters(123, (4294967295 - 100)).should == 223
  end
  
  it "should compute per second disk I/O values" do
    older_raw_stats = {"reads"=>10_000, "writes"=>5000, "sectors_written"=>40_000, "sectors_read"=>200_000}
    newer_raw_stats = {"reads"=>20_000, "writes"=>10_000, "sectors_written"=>80_000, "sectors_read"=>400_000}
    result = @sys_stats.disk_io_per_s(newer_raw_stats, older_raw_stats, 2)
    result.should == {"reads/s"=>5_000,"writes/s"=>2_500,"bytes_written/s"=>(20_000*512),"bytes_read/s"=>(100_000*512)}
  end
  
  it "should give disk I/O stats for supported platforms" do
    t = Time.now
    raw_stats_1 = {"time" => t.to_f, "dm-0" => {"reads"=>0, "writes"=>0, "sectors_written"=>0, "sectors_read"=>0}}
    raw_stats_2 = {"time" => (t + 2).to_f, "dm-0" => {"reads"=>1000, "writes"=>500, "sectors_written"=>4000, "sectors_read"=>8000}}
    raw_stats_3 = {"time" => (t + 4).to_f, "dm-0" => {"reads"=>3000, "writes"=>1500, "sectors_written"=>12_000, "sectors_read"=>24_000}}
    @sys_stats.should_receive(:raw_diskstats).and_return(raw_stats_1, raw_stats_2, raw_stats_3)
    @sys_stats.diskstats.should be_nil
    @sys_stats.diskstats.should == {"dm-0" => {"reads/s" => 500.0, "writes/s" => 250.0, "bytes_written/s" => (2000.0 * 512), "bytes_read/s" => (4000.0 * 512)}}
    @sys_stats.diskstats.should == {"dm-0" => {"reads/s" => 1000.0, "writes/s" => 500.0, "bytes_written/s" => (4000.0 * 512), "bytes_read/s" => (8000.0 * 512)}}
  end
  
  it "should get load averages for supported platforms" do
    File.expects(:open).with("/proc/loadavg", "r").returns(SAMPLE_LOADAVG.split("\n"))
    loadavg = @sys_stats.loadavg
    loadavg.delete("time")
    loadavg.should == {"1"=> "0.11", "5" => "0.55", "10"=> "0.10", "processes" => "185"}
  end
  
  it "should get raw network statistics for supported platforms" do
    File.expects(:open).with("/proc/net/dev", "r").returns(SAMPLE_NETDEV.split("\n"))
    netstats = @sys_stats.raw_netstats
    netstats.keys.should == ["eth0", "lo", "time"]
    netstats["eth0"].should == {"receive_bytes"=>72933, "receive_packets"=>810, "sent_bytes"=>67226, "sent_packets"=>454}
    netstats["lo"].should == {"receive_bytes"=>0, "receive_packets"=>0, "sent_bytes"=>0, "sent_packets"=>0}
  end
  
  it "should give network stats for supported platforms" do
    t = Time.now
    raw_stats_1 = {"time" => t.to_f, "eth0"=>{"receive_bytes"=>1_000, "receive_packets"=>200, "sent_bytes"=>2_000, "sent_packets"=>400}}
    raw_stats_2 = {"time" => (t + 2).to_f, "eth0"=>{"receive_bytes"=>2_000, "receive_packets"=>400, "sent_bytes"=>4_000, "sent_packets"=>800}}
    @sys_stats.should_receive(:raw_netstats).and_return(raw_stats_1, raw_stats_2)
    @sys_stats.netstats.should == nil
    @sys_stats.netstats.should == {"eth0" => {"receive_bytes/s"=>500.0,"receive_packets/s"=>100.0,"sent_bytes/s"=>1000.0,"sent_packets/s"=>200.0}}
  end
  
end