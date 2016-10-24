#!/usr/bin/ruby

require 'expect'
require 'rubyserial'
require 'optparse'

# 'Fast' downloader for flash / blackbox files
# Requires iNav compliation with "USE_FLASH_TOOLS=1"

class Serial
  # Expose the rubyserial file descriptor for select(3) on POSIX systems.
  def getfd
    @fd
  end
end

serdev="/dev/ttyUSB0"
ofile=Time.now.strftime "bblog_%F%H%M%S.TXT"
baud = 115200
erase= false

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] file\nDownload bb from flash"
  opt.on('-s','--serial-device=DEV'){|o|serdev=o}
  opt.on('-e','--erase'){erase=true}
  opt.on('-o','--output=FILE'){|o| ofile=o}
  opt.on('-b','--baud=RATE',Integer){|o|baud=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

delok = false
sport = Serial.new serdev,baud
sfd = sport.getfd
sio = IO.new(sfd)

sport.write "#"
res = sio.expect("#",10)
abort "Failed to read FC" if res.nil?

sport.write "flash_info\n"
res = sio.expect(/usedSize=(\d+)\r/, 5)
if res && res.length == 2
  fsize = res[1].to_i
  if fsize > 0
    rbytes = 0
    sport.write("flash_read 0 #{fsize}\n")
    res = sio.expect("flash_read 0 #{fsize}\r\nReading #{fsize} bytes at 0:\r\n",1)
    if res
      File.open(ofile, "wb") do |fh|
	n = 0
	rtim = 9999
	loop do
	  data = sio.read(256)
	  unless data.nil?
	    rsize = data.length
	    rbytes += rsize
	    rbytes = fsize if rbytes > fsize
	    if n % 4 == 0
	      rem = fsize - rbytes
	      rtim = rem*10/baud
	    end
	    print "\rread #{rbytes} / #{fsize} %4ds\r" % rtim
	    n += 1
	    fh.write data
	    if rbytes == fsize
	      delok = true
	      break
	    end
	  end
	end
      end
    end
    puts
  else
    delok = true
  end
end

if delok && erase
  puts "Erasing"
  sport.write("flash_erase\n")
  sio.expect "Done", 300
  puts "Done"
end

sport.write "exit\n"
sio.expect("Rebooting")
