#!/usr/bin/env ruby
require 'pty'

# Requires a "V2" rawlog
RLEN=11
UPS="dSa"
pid = nil
cld = true

at_exit do
  if pid
    Process.kill('TERM', pid)
    Process.wait pid
  end
end

Signal.trap("CLD") do
  cld = false
end

abort "test.rb raw.log [output_file]" unless ARGV.length > 0
outf = (ARGV[1]||"/tmp/cap.json")
File.open(ARGV[0]) do |f|
  s = f.read(3)
  if s == "v2\n" # requires mwp V2 metadata raw log
    lt = 0.0
    PTY.open do |io, slave|
      slave.close
      pid = spawn("mwp-serial-cap -js -d #{slave.path} #{outf}")
      loop do
        s = f.read(RLEN)
        break if s.nil?
        break if !cld
        ts,len,dir=s.unpack(UPS)
        data = f.read(len)
        io.write data
        sleep ts-lt
        lt = ts
      end
    end
  end
end
