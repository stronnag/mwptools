#!/usr/bin/ruby

require 'socket'
require 'optparse'

host='::'
port=43210
verbose=rest=create=false
delay = 0.00167

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
  bytes = IO.read(fn)
  bytes.each_byte do |b|
    begin
      session.send(b.chr,0)
    rescue
      break
    end
    sleep delay
  end
  STDERR.puts "#{Time.now.strftime("%FT%T")} disconnect #{peer_str}"
  begin session.close rescue nil end
end
server.close
