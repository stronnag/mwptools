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

delay = 0.00167
baud=115200
dev="/dev/ttyUSB0"

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
bytes = IO.read(fn)
bytes.each_byte do |b|
  begin
    fd.write b.chr
  rescue
    break
  end
  sleep delay
end
