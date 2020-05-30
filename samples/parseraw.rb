#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# MIT licence

require 'optparse'
require 'socket'

begin
require 'rubyserial'
  noserial = false;
rescue LoadError
  noserial = true;
end

port = nil
rawf = nil
dev = nil
skip = false
fdel = nil
in_only = out_only = ltm_only = raw = omitx = false

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-u','--udp PORT'){|o| port=o}
  opt.on('-d','--device DEV'){|o| dev=o}
  opt.on('-i','--input') {in_only = true}
  opt.on('-o','--output') {out_only = true}
  opt.on('-l','--ltm') {ltm_only = true}
  opt.on('--omit-x-frame') {omitx = true}
  opt.on('-r','--raw') {raw = true}
  opt.on('-d','--delay=N',Float) {|o| fdel = o}
  opt.on('-s','--skip-first','skip any initial delay for udp') {skip = true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

skt=nil
host=nil
lt = 0

if port
  if(m = port.match(/(\S+):(\d+)/))
    host = (m[1]||'localhost')
    port = m[2].to_i
  else
    port = port.to_i
    host = 'localhost'
  end
  addrs = Socket.getaddrinfo(host, port,nil,:DGRAM)
  skt = ((addrs[0][0] == 'AF_INET6') ? UDPSocket.new(Socket::AF_INET6) : UDPSocket.new)

  Thread.new do
    while true
      msg, sender = skt.recvfrom(128)
      rem = sender[3]
      STDOUT.puts "RECV #{msg.size}b from #{rem}"
    end
  end
end

if raw
  rawf = File.open("raw_dump.txt", 'w')
end

if dev
  if noserial
    dev = File.open(dev, 'w')
  else
    dev = Serial.new dev,115200
  end
end

upackstr = 'dca'
rlen=10

puts ARGV[0]
File.open(ARGV[0]) do |f|
  s = f.read(3)
  if s == "v2\n"
    rlen = 11
    upackstr = 'dSa'
  else
    rlen = 10
    upackstr = 'dCa'
    f.rewind
  end

  loop do
    s = f.read(rlen)
    break if s.nil?
    ts,len,dir=s.unpack(upackstr)
    data = f.read(len)
    next if in_only && dir == "o"
    next if out_only && dir == "i"
    next if ltm_only && data[1] != 'T'
    puts "offset #{ts} len #{len} #{dir}"
    if data[0] == '$' && data[1]  == 'M' && len > 4
      STDOUT.printf "MSP %d :" ,data[4].ord
    end

    if data[0].ord == 0xfe  && len > 5
      STDOUT.printf "Mav %d :" ,data[5].ord
    end

    puts data.inspect
    data.each_byte do |b|
      STDOUT.printf "%02x ",b
    end
    puts
    if raw
      if !(omitx && data[1] == 'T' && data[2] == 'X')
	rawf.print data
      end
    end

    if fdel
      delta = fdel
    else
      delta = ts-lt
    end

    puts "%10.6f sleep\n" % delta
    if dev
      if !(omitx && data[1] == 'T' && data[2] == 'X')
	dev.write data
	sleep delta if skip == false or delta.zero?
      end
    end


    if skt
      if data[1] == 'T'
	next if omitx && data[2] == 'X'
      end
      sleep delta if skip == false or delta.zero?
      skip = false if(skip)
      skt.send data,0,host,port
    end
    lt=ts
  end
end
if raw
  rawf.close
end
if dev
  dev.close
end
