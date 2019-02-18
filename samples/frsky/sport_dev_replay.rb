#!/usr/bin/ruby

require 'optparse'
require 'rubyserial'

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

baud=115200
dev="/dev/ttyUSB0"
delay = nil

ARGV.options do |opt|
  opt.banner = "Usage: #{File.basename $0} [options] file"
  opt.on('-d','--delay SECS',Float, "#{delay}") {|o| delay=o}
  opt.on('-s','--serial DEVICE',String, "#{dev}") {|o| dev=o}
  opt.on('-b','--baud RATE',Integer, "#{baud}") {|o| baud=o}
  opt.on('-?', "--help", "Show this message") {puts opt; exit}
  rest = opt.parse!
end

fn = ARGV[0]||abort("file please (ARGV[0]) ....")

STDERR.puts "Note: sending starts immediately, hope your consumer is ready"
fd = Serial.new dev, baud
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
	fd.write data.to_s
	sleep delta*delay
	lt = ts
      end
    else
      begin
	b = f.readbyte
	fd.write b.chr
      rescue
	break
      end
      sleep delay
    end
  end
end
