#!/usr/bin/ruby
require 'ap'
require 'optparse'
require 'rubyserial'

# This is a trivial RAW_RC / RC tester
# just for those who claim it doesn't work .... wrong

class Serial
  # Expose the rubyserial file descriptor for select(3) on POSIX systems.
  def getfd
    @fd
  end
  def setvtime t
    @config[:cc_c][RubySerial::Posix::VTIME] = t
    RubySerial::Posix.tcsetattr(@fd, RubySerial::Posix::TCSANOW, @config)
  end
end

class MSP

  HDR="$M<"
  DEV='/dev/ttyUSB0'

  S_END=0
  S_HEADER=1
  S_SIZE=2
  S_CMD=3
  S_DATA=4
  S_CHECKSUM=5
  S_ERROR=6

  MSP_API_VERSION=1
  MSP_IDENT=100
  MSP_STATUS=101
  MSP_MISC=114
  MSP_ALTITUDE=109
  MSP_SET_RAW_RC=200
  MSP_RC=105
  MSP_MOTOR=104
  MSP_RAW_IMU=102
  MSP_ATTITUDE=108
  MSP_RC_TUNING=111
  MSP_CONTROL=120
  MSP_RAW_GPS=106
  MSP_COMP_GPS=107
  MSP_ACC_CALIBRATION=205
  MSP_MAG_CALIBRATION=206
  MSP_SERVO_CONF=120
  MSP_SET_SERVO_CONF=212
  MSP_BOXNAMES = 116
  MSP_BOXIDS = 119
  MSP_BOX = 113
  MSP_SET_BOX = 203
  MSP_WP = 118

  def cksum(s,init=0)
    ck=init
    s.each_byte do |c|
    ck ^= c
    end
    ck
  end

  def read_data
    data_to_read=1
    state=S_HEADER
    checksum=0
    ok=false
    data_raw=''
    data_size=0
    cmd=nil
    while (state!=S_END) and (state!=S_ERROR) do
      c=@fd.read(data_to_read)
      case state
      when S_HEADER
	if c == '$'
	  c=@fd.read(2)
	  if c=='M>' or c=='M!'
	    state=S_SIZE
	  else
	    puts "Error in header"
	    state=S_ERROR
	  end
	else
	  puts "Error: No header received"
	  state=S_ERROR
	end
      when S_SIZE
	data_size=c.ord
	checksum ^= data_size
	state=S_CMD
      when S_CMD
	cmd=c.ord
	checksum ^= cmd
	if data_size == 0
	  data_to_read=1
	  state=S_CHECKSUM
	else
	  data_to_read = data_size
	  state=S_DATA
	end
      when S_DATA
	data_raw=c
	checksum = cksum(data_raw, checksum)
	state=S_CHECKSUM
	data_to_read=1
      when S_CHECKSUM
	ck=c.ord
	if checksum != ck
	  puts "Error in checksum"
	  state=S_ERROR
	else
	  state=S_END
	end
      end
    end
    if state == S_END
      ok=true
    else
    end
    [ok,cmd,data_raw]
  end

  def write cmd
    @fd.write cmd
  end

  def encode_data cmd,data
    dsize = data.size
    sdata = "#{dsize.chr}#{cmd.chr}#{data}"
    ck =  cksum(sdata)
    "#{HDR}#{sdata}#{ck.chr}"
  end

  def send_data cmd,data
    mwdata=encode_data cmd,data
    @fd.write mwdata
  end

  def do_command wanted,data
    buf=nil
    ok=false
    loop do
      send_data wanted,data
      ok,cmd,buf=read_data
      break if cmd == wanted
      puts "retry #{cmd} #{wanted}"
    end
    [buf,ok]
  end

  def initialize dev=DEV,baud=115200
    puts "dev #{dev} #{baud}"
    @fd = Serial.new dev, baud
    @fd.setvtime 10
  end
end

dev=MSP::DEV
rate=115200
profiles=nil
tyaw=false
sfile=nil
prarry = [0]

ARGV.options do |opt|
  opt.banner = "set_raw_rc"
  opt.banner << "\nUsage: #{File.basename $0} [options] file"
  opt.on('-d',"--device DEV") {|o| dev=o}
  opt.on('-b',"--baudrate RATE", Integer) {|o| rate=o}
  opt.on('-?', "--help", "Show this message") {puts opt; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

m = MSP.new dev,rate

buf = m.do_command(MSP::MSP_IDENT,'')
b=buf[0].unpack('CCCL')
ap b
sleep 0.1
loop do
  a = 1500+rand(100)
  e = 1500+rand(100)
  t = 1500+rand(100)
  r = 1500+rand(100)
  str=[a,e,r,t,1017,1442,1663,1969].pack('ssssssss')
  res = m.do_command  MSP::MSP_SET_RAW_RC, str
  puts "Tx: #{[a,e,t,r,1017,1442,1663,1969].join(',')}"
  sleep 0.01
  if res
    buf = m.do_command  MSP::MSP_RC, ''
    b = buf[0].unpack('ssssssss')
    puts "Rx: #{b.join(',')}"
    sleep 0.01
  end
  puts
end
