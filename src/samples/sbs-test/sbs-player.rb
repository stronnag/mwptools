#!/usr/bin/env ruby

require 'socket'
require 'optparse'
require 'time'

def handle_client(s, fnam, once)
  Thread.new do
    lts = nil
    peer = "#{s.peeraddr[3]}:#{s.peeraddr[1]}"
    File.open(fnam) do |fh|
      fh.each do |l|
        l.chomp!
        a = l.split(',')
        ts  = Time.parse([a[8],a[9]].join(' '))
        sleep ts - lts if lts
        s.puts l rescue break
        lts = ts
      end
    end
    STDERR.puts "--- Close session #{peer}"
    s.close rescue nil
    Kernel.exit if once
  end
end


host='::'
port=30003
once=nil

ARGV.options do |opt|
  opt.banner = "Usage: netcap.rb [options] file"
  opt.on('-p','--port PORT',Integer, port) {|o| port=o}
  opt.on('--once') {once=true}
  opt.parse!
end
fnam = ARGV.shift
server = TCPServer.new(host,port)
server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR,1)
while (session = server.accept)
  peer = "#{session.peeraddr[3]}:#{session.peeraddr[1]}"
  STDERR.puts "++ New session #{peer}"
  handle_client(session, fnam, once)
end
