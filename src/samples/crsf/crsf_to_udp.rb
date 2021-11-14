#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# MIT licence

require 'optparse'
require 'socket'

port = "40042"
host = 'localhost'
delay = 0.01

ARGV.options do |opt|
  opt.on('-d','--delay SECS', Float){|o| delay=o}
  opt.on('-u','--udp PORT'){|o| port=o}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

if ARGV.size == 0
  abort "Need a file to replay"
end

if(m = port.match(/(\S+):(\d+)/))
  host = (m[1]||'localhost')
  port = m[2].to_i
else
  port = port.to_i
end
addrs = Socket.getaddrinfo(host, port,nil,:DGRAM)
skt = ((addrs[0][0] == 'AF_INET6') ? UDPSocket.new(Socket::AF_INET6) : UDPSocket.new)

n = 0;
File.open(ARGV[0]) do |f|
  loop do
    s = f.read(16)
    break if s.nil?
    print "\rread #{s.length} @ #{n}"
    skt.send s,0,host,port
    sleep (delay)
    n += s.length
  end
end
puts "\n\n"
