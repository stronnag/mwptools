#!/usr/bin/ruby

require 'socket'
require 'optparse'

host='::'
port=43210
verbose=rest=create=false
delay = nil

ARGV.options do |opt|
  opt.banner = "Usage: #{File.basename $0} [options] file"
  opt.on('-p','--port PORT',Integer, "#{port}") {|o| port=o}
  opt.on('-d','--delay SECS',Float, "#{delay}") {|o| delay=o}
  opt.on('-?', "--help", "Show this message") {puts opt; exit}
  rest = opt.parse!
end

fn = ARGV[0]||abort("file please ....")
server = TCPServer.new(host,port)
server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR,1)
STDERR.puts "Waiting for a connection ...."
while (session = server.accept)
  peer_str = "#{session.peeraddr[3]}:#{session.peeraddr[1]}"
  STDERR.puts "#{Time.now.strftime("%FT%T")} connect #{peer_str}"
  rlen = nil
  lt = 0
  File.open(ARGV[0]) do |f|
    s = f.read(3)
    if s == "v2\n"
      rlen = 11
      delay = 1.0 if delay == nil
      STDERR.puts "playing mwp raw capture with factor #{delay}"
    else
      f.rewind
      delay = 0.00167 if delay == nil
      STDERR.puts "playing byte stream capture with delay #{delay}"
    end

    loop do
      if rlen
	s = f.read(rlen)
	break if s.nil?
	ts,len,dir=s.unpack('dSa')
	data = f.read(len)
	if dir == 's'
	  delta = ts-lt
	  session.send(data.to_s,0)
	  sleep delta*delay
	  lt = ts
	end
      else
	begin
	  b = f.readbyte
	  session.send(b.chr,0)
	rescue
	  break
	end
	sleep delay
      end
    end
  end
  STDERR.puts "#{Time.now.strftime("%FT%T")} disconnect #{peer_str}"
  begin session.close rescue nil end
end
server.close
