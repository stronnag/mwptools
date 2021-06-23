#!/usr/bin/ruby
require 'pty'

# Requires a "V2" rawlog
RLEN=11
UPS="dSa"
pid = nil

at_exit do
  Process.kill('TERM', pid) if pid
end

File.open(ARGV[0]) do |f|
  s = f.read(3)
  if s == "v2\n" # requires mwp V2 metadata raw log
    lt = 0.0
    PTY.open do |io, slave|
      pid = spawn("mwp-serial-cap -js -d #{slave.path} /tmp/cap.txt")
      loop do
        s = f.read(RLEN)
        break if s.nil?
        ts,len,dir=s.unpack(UPS)
        data = f.read(len)
        io.print data
        sleep ts-lt
        lt = ts
      end
    end
  end
end
