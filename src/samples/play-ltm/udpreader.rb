#!/usr/bin/ruby
require 'socket'

port=(ARGV.shift || 3810).to_i
srv=UDPSocket.open
srv.bind('',port)
while l = srv.recv(1024)
  print "Recv #{l[2]} (#{l.size})\n"
  break if l[2] == 'S' and l[9].ord == 0
end
