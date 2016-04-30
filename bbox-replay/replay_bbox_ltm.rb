#!/usr/bin/env ruby

# Copyright (c) 2015 Jonathan Hudson <jh+mwptools@daria.co.uk>

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'csv'
require 'optparse'
require 'socket'
require 'open3'
require 'json'

begin
require 'rubyserial'
  noserial = false;
rescue LoadError
  noserial = true;
end

class Serial
  # Expose the rubyserial file descriptor for select(3) on POSIX systems.
  def getfd
    @fd
  end
end

LLFACT=10000000
ALTFACT=100

def start_io dev
  if RUBY_PLATFORM.include?('cygwin') || !Gem.win_platform?
    # Easy way for Linux and OSX
    res = select [STDIN,dev[:io]],nil,nil,nil
    case res[0][0]
    when dev[:io]
      if dev[:type] == :ip
	res = dev[:io].recvfrom(256)
	dev[:host] = res[1][3]
	dev[:port] = res[1][1].to_i
      end
    end
  else
    # Ugly way for Windows
    require 'win32api'
    t1=t2 = nil
    res=nil
    t1 = Thread.new do
      kbhit = Win32API.new('crtdll', '_kbhit', [ ], 'I')
        loop do
	break if kbhit.Call == 1
	sleep 0.1
      end
      t2.kill
    end
    t2 = Thread.new do
      if dev[:type] == :ip
          res = dev[:io].recvfrom(256)
	t1.kill
	dev[:host] = res[1][3]
	dev[:port] = res[1][1].to_i
      else
	dev[:serp].read(1)
	t1.kill
      end
      end
    t1.join
    t2.join
    if dev[:type] == :ip
	puts "peer #{dev[:host]}:#{dev[:port]}"
    end
  end
end

def mksum s
  ck = 0
  s.each_byte {|c| ck ^= c}
  ck
end

def send_msg dev, msg
  if !dev.nil? and !msg.nil?
    case dev[:type]
    when :ip
      dev[:io].send msg, 0, dev[:host], dev[:port]
    when :tty
      dev[:serp].write(msg)
    when :fd
      dev[:io].syswrite(msg)
    end
  end
end

def send_init_seq skt,typ,snr=false,baro=true

  msps = [
    [0x24, 0x4d, 0x3e, 0x07, 0x64, 0xe7, 0x01, 0x00, 0x3c, 0x00, 0x00, 0x80, 0],
    [0x24, 0x4d, 0x3e, 0x03, 0x01, 0x00, 0x01, 0x0e, 0x0d],
    [0x24, 0x4d, 0x3e, 0x04, 0x02, 0x49, 0x4e, 0x41, 0x56, 0x16],
    [0x24, 0x4d, 0x3e, 0x03, 0x03, 0, 42, 0x00, 42], # obviously fake
    [0x24,0x4d,0x3e,0x9f,0x74,0x41,0x52,0x4d,0x3b,0x41,0x4e,0x47,0x4c,0x45,0x3b,0x48,0x4f,0x52,0x49,0x5a,0x4f,0x4e,0x3b,0x41,0x49,0x52,0x20,0x4d,0x4f,0x44,0x45,0x3b,0x48,0x45,0x41,0x44,0x49,0x4e,0x47,0x20,0x4c,0x4f,0x43,0x4b,0x3b,0x4d,0x41,0x47,0x3b,0x48,0x45,0x41,0x44,0x46,0x52,0x45,0x45,0x3b,0x48,0x45,0x41,0x44,0x41,0x44,0x4a,0x3b,0x4e,0x41,0x56,0x20,0x41,0x4c,0x54,0x48,0x4f,0x4c,0x44,0x3b,0x53,0x55,0x52,0x46,0x41,0x43,0x45,0x3b,0x4e,0x41,0x56,0x20,0x50,0x4f,0x53,0x48,0x4f,0x4c,0x44,0x3b,0x4e,0x41,0x56,0x20,0x52,0x54,0x48,0x3b,0x4e,0x41,0x56,0x20,0x57,0x50,0x3b,0x48,0x4f,0x4d,0x45,0x20,0x52,0x45,0x53,0x45,0x54,0x3b,0x47,0x43,0x53,0x20,0x4e,0x41,0x56,0x3b,0x42,0x45,0x45,0x50,0x45,0x52,0x3b,0x4f,0x53,0x44,0x20,0x53,0x57,0x3b,0x42,0x4c,0x41,0x43,0x4b,0x42,0x4f,0x58,0x3b,0x46,0x41,0x49,0x4c,0x53,0x41,0x46,0x45,0x3b,0xa7],
    [0x24, 0x4d, 0x3e, 11,   101,  0, 0, 0, 0, 0, 0, 4,0,0,0, 0, 0], # obviously fake
  ]

  sensors = (1|4|8)

  if baro
    sensors |= 2
  end

  if snr
    sensors |= 16
  end

  msps[5][9] = sensors
  if typ
    msps[0][6] = typ
  end
  msps.each do |msp|
    msp[-1] = mksum msp[3..-2].pack('C*')
    send_msg skt, msp.pack('C*')
    sleep 0.01
  end
end

def encode_atti r, gpshd=0
  msg='$TA'
  hdr = case gpshd
	when 1
	  r[:gps_ground_course].to_i
	when 2
	  r[:heading].to_i
	else
	  r[:attitude2].to_i/10
	end

  sl = [r[:pitch].to_i, r[:roll].to_i, hdr].pack("s<s<s<")
  msg << sl << mksum(sl)
  msg
end

def encode_gps r,baro=true
  msg='$TG'
  nsf = 0
  ns = r[:gps_numsat].to_i
  if r.has_key? :gps_fixtype
    nsf = r[:gps_fixtype].to_i + 1
  else
    nsf = case ns
	  when 0
	    0
	  when 1,2,3,4
	    1
	  when 5,6
	    2
	  else
	    3
	  end
  end
  nsf |= (ns << 2)

  alt = (baro) ? r[:baroalt_cm].to_i : r[:gps_altitude]*100.to_i

  sl = [(r[:gps_coord0].to_f*LLFACT).to_i,
    (r[:gps_coord1].to_f*LLFACT).to_i,
    r[:gps_speed_ms].to_i,
    alt, nsf].pack('l<l<CL<c')
  msg << sl << mksum(sl)
  msg
end

def encode_origin r
  msg='$TO'
  sl = [(r[:lat].to_f*LLFACT).to_i,
    (r[:lon].to_f*LLFACT).to_i,
    (r[:alt].to_f*ALTFACT).to_i,
    1,1].pack('l<l<L<cc')
  msg << sl << mksum(sl)
  msg
end

def encode_stats r,armed=1
  msg='$TS'
  sts = case r[:navstate].to_i
	when 0,1
	  0 # get from flightmode
	when 2,3
	  8
	when 4..7
	  9
	when 8..16
	  13
	when 18..21
	  15
	when 22..26
	  10
	else
	  19
	end
  sts = (sts << 2) | armed
  sl = [(r[:vbatlatest_v].to_f*1000).to_i, 0, 0, 0, sts].pack('S<S<ccc')
  msg << sl << mksum(sl)
  msg
end

def encode_nav r
  msg='$TN'
  gpsmode = case r[:navstate].to_i
	 when 4..7
	   1
	 when 8..21
	   2
	when 22..26
	   3
	else
	   0
	end
  navmode = case r[:navstate].to_i
	    when 2..3
	      99
	    when 4..7
	      3
	    when 8,9,14,16
	      1
	    when 18
	      8
	    when 19
	      9
	    when 20
	      11
	    when 21
	      10
	    when 22..26
	      5
	    else
	      0
	    end
  navact = case gpsmode
	   when 3
	     1
	   when 1
	     2
	   when 2
	     case r[:navstate].to_i
	     when 27..29,18..21
	       8
	     else
	       4
	     end
	   else
	     0
	   end
  sl = [gpsmode,navmode,navact,0,0,0].pack('CCCCCC')
  msg << sl << mksum(sl)
  msg
end

def encode_extra r
  msg='$TX'
  sl = [r[:gps_hdop].to_i].pack('v')
  msg << sl << mksum(sl)
  msg
end

def get_autotype file
  dirname = File.dirname(file)
  files = Dir["#{dirname}/mwp_*.log"]
  mtyp = nil
  fn = nil
  if files.empty?
    fn = file.dup
    fn = fn.gsub!(/\.TXT$/,".log")
  else
    fn = files[0]
  end

  if fn != nil
    if File.exist? fn
      File.open(fn) do |fh|
	json = fh.readline
	o = JSON.parse(json, {:symbolize_names => true})
	if o[:type] == 'init'
	  mtyp = o[:mrtype]
	end
	break
      end
    end
  end
  mtyp
end

unless RUBY_VERSION.match(/^2/)
  abort "This script requires a miniumum of Ruby 2.0"
end

idx = 1
decl = -1.5
typ = 3
udpspec = nil
serdev = nil
v4 = false
gpshd = 0
mindelay = false
childfd = nil
lhdop = 100000
autotyp=nil

pref_fn = File.join(ENV["HOME"],".config", "mwp", "replay_ltm.json")
if File.exist? pref_fn
  json = IO.read(pref_fn)
  prefs = JSON.parse(json, {:symbolize_names => true})
  decl = prefs[:declination].to_f
  autotyp = prefs[:auto]
end

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] file\nReplay bbox log as LTM"
  opt.on('-u','--udp=ADDR',String,"udp target (localhost:3000)"){|o|udpspec=o}
  opt.on('-s','--serial-device=DEV'){|o|serdev=o}
  opt.on('-i','--index=IDX',Integer){|o|idx=o}
  opt.on('-t','--vehicle-type=TYPE',Integer){|o|typ=o}
  opt.on('-d','--declination=DEC',Float,'Mag Declination (default -1.5)'){|o|decl=o}
  opt.on('-g','--force-gps-heading','Use GPS course instead of compass'){gpshd=1}
  opt.on('-4','--force-ipv4'){v4=true}
  opt.on('-m','--use-imu-heading'){gpshd=2}
  opt.on('-f','--fast'){mindelay=true}
  opt.on('--fd=FD',Integer){|o| childfd=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

dev = nil
intvl = 100000
nv = 0
icnt = 0
origin = nil

begin
  fds=nil
  fds = Open3.capture3('blackbox_decode --help')
rescue
  abort "Can't run 'blackbox_decode' is it installed and on the PATH?"
end

bbox = (ARGV[0]|| abort('no BBOX log'))
if autotyp && typ == 3
  typ = (get_autotype(bbox) || typ)
end

if udpspec
  fd = nil
  dev = {:type => :ip, :mode => nil}
  h = p = nil
  if(m = udpspec.match(/(?:udp:\/\/)?(\S*)?:{1}(\d+)/))
    h = m[1]
    p = m[2].to_i
  else
    abort "can't parse UDP spec"
  end
  addrs = Socket.getaddrinfo(nil, p,nil,:DGRAM)
  if v4 == false && addrs[0][0] == 'AF_INET6'
   fd = UDPSocket.new Socket::AF_INET6
    if h.empty?
      h = '::'
      dev[:mode] = :bind
    end
  else
    fd = UDPSocket.new
    if h.empty?
      h = ''
      dev[:mode] = :bind
    end
  end
  if dev[:mode] == :bind
    fd.bind(h, p)
  else
    fd.connect(h, p)
    dev[:host] = h
    dev[:port] = p
  end
  dev[:io] = fd
elsif serdev
  if noserial == true
    abort "No rubyserial gem found"
  end
  sdev,baud = serdev.split('@')
  baud ||= 115200
  baud = baud.to_i
  serialport = Serial.new sdev,baud
  dev = {:type => :tty, :serp => serialport}
  if !Gem.win_platform?
    sfd = serialport.getfd
    dev[:io] = IO.new(sfd)
  end
elsif childfd
  dev = {:type => :fd, :io => IO.new(childfd)}
else
  abort 'no device / UDP port'
end

if (dev[:type] == :tty || dev[:type] == :fd || dev[:mode] == :bind)
  print "Waiting for GS to start (RETURN to continue) : "
  start_io dev
  if dev[:mode] == :bind and (dev[:host].nil? or dev[:host].empty?)
    puts "UDP peer is undefined"
    exit
  else
    puts ' ... OK'
  end
end

nul="/dev/null"
csv_opts = {
  :col_sep => ",",
  :headers => :true,
  :header_converters => ->(f){f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
  :return_headers => true}

if Gem.win_platform?
  nul = "NUL"
  csv_opts[:row_sep] = "\r\n" if RUBY_PLATFORM.include?('cygwin')
end
cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --merge-gps"
cmd << " --declination #{decl}"
cmd << " --simulate-imu"
cmd << " --stdout"
cmd << " 2>#{nul}"
cmd << " \"#{bbox}\""

lastr =nil
llat = 0.0
llon = 0.0

IO.popen(cmd,'rt') do |pipe|
  csv = CSV.new(pipe, csv_opts)
  hdrs = csv.shift
  abort 'Not an INAV log' if hdrs[:gps_coord0].nil?

  have_sonar = (hdrs.has_key? :sonarraw)
  have_baro = true # until confirmed ...
  #  have_baro = (hdrs.has_key? :baroalt_cm)

  send_init_seq dev,typ,have_sonar,have_baro

  csv.each do |row|
    next if row[:gps_numsat].to_i == 0
    us = row[:time_us].to_i
    if us > nv
      nv = us + intvl
      icnt  = (icnt + 1) % 10
      msg = encode_atti row, gpshd
      send_msg dev, msg
      case icnt
      when 0,2,4,6,8
	llat = row[:gps_coord0].to_f
	llon = row[:gps_coord1].to_f
	if  llat != 0.0 and llon != 0.0
	  msg = encode_gps row, have_baro
	  send_msg dev, msg
	  if origin.nil? and row[:gps_numsat].to_i > 4
	    origin = {:lat => row[:gps_coord0], :lon => row[:gps_coord1],
	      :alt => row[:gps_altitude]}
	    msg = encode_origin origin
	    send_msg dev, msg
	  end
	end
      when 5
	if  llat != 0.0 and llon != 0.0 && origin
	  msg = encode_origin origin
	  send_msg dev, msg
	end
	if row.has_key? :gps_hdop
	  hdop = row[:gps_hdop].to_i
	  if hdop != lhdop
	    msg = encode_extra row
	    send_msg dev, msg
	  end
	  lhdop = hdop
	end
      when 1,3,7,9
	if  llat != 0.0 and llon != 0.0
	  lastr = row
	  msg = encode_stats row
	  send_msg dev, msg
	  msg = encode_nav row
	  send_msg dev, msg
	end
      end
      sleep (mindelay) ? 0.001 : 0.1
    end
  end
end
# fake up a few disarm messages
if lastr
  msg = encode_stats lastr,0
  0.upto(5) do
    send_msg dev, msg
    sleep 0.1
  end
end
