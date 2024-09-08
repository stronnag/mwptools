#!/usr/bin/ruby

require 'expect'
require 'rubyserial'
require 'optparse'

# 'Fast' downloader for flash / blackbox files
# Requires iNav compliation with "USE_FLASH_TOOLS=1"
# MIT licence

class Serial
  # Expose the rubyserial file descriptor for select(3) on POSIX systems.
  def getfd
    @fd
  end
  def set_vtime t
    @config[:cc_c][RubySerial::Posix::VTIME] = t
    RubySerial::Posix.tcsetattr(@fd, RubySerial::Posix::TCSANOW, @config)
  end
end


SBAUD = [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 250000, 460800, 921600, 1000000, 1500000, 2000000]

Encoding.default_external = Encoding::BINARY

serdev=nil
serdevs={"/dev/ttyUSB0" => '0', "/dev/ttyACM0" => '20'}
sid = '0'

serdevs.each do |k,v|
  if File.exists? k
    serdev = k
    sid = v
    break
  end
end

puts serdev

ofile=Time.now.strftime "bblog_%F-%H%M%S.TXT"
baud = 115200
sbaud=nil
erase= false
x_erase = false

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] file\nDownload bb from flash"
  opt.on('-s','--serial-device=DEV'){|o|serdev=o}
  opt.on('-e','--erase'){erase=true}
  opt.on('-E','--erase-only'){x_erase=true}
  opt.on('-o','--output=FILE'){|o| ofile=o}
  opt.on('-b','--baud=RATE',Integer){|o|baud=o}
  opt.on('-B','--super-baud=RATE',Integer){|o|sbaud=o}
  opt.on('-S','--show-super-rates') { puts SBAUD ; exit }
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

unless sbaud.nil?
  abort "Unsupported super-baudrate" unless SBAUD.include?(sbaud)
end

delok = false
defser = nil
xfsize = 0
stm = 0

sport = Serial.new serdev,baud
sport.set_vtime 1
sfd = sport.getfd
sio = IO.new(sfd)

sport.write "#"
res = sio.expect("#",10)
abort "Failed to read FC" if res.nil?

if sbaud
  puts "Changing baud rate to #{sbaud}\n"
  sport.write "serial\n"
  res = sio.expect("# ",5)
  if m=res[0].match(/.*(serial #{sid} \d+ \d+ \d+ \d+ \d+)/)
    puts "Found \"#{m}\""
    defser = m[0]
    params = m[0].split
    params[3] = sbaud
    ns = params.join(' ')
    puts "setting #{ns}"
    sport.write("#{ns}\n")
    res = sio.expect("# ",1)
    sport.write "save\n"
    sio.expect("Rebooting")
    sport.close
    sleep 4
    loop do
      if File.exists? serdev
	break
      else
	sleep 1
      end
    end
    sport = Serial.new serdev,sbaud
    sfd = sport.getfd
    sio = IO.new(sfd)
    sport.write "#"
    res = sio.expect("#",10)
    abort "Failed to read FC" if res.nil?
    puts "Reopened at #{sbaud}\n"
  end
end

sport.write "flash_info\n"
res = sio.expect(/usedSize=(\d+)\r/, 5)

rbaud = (sbaud) ? sbaud : baud

unless x_erase
  begin
    if res && res.length == 2
      fsize = res[1].to_i
      unless  ENV['TEST_USED'].nil?
	fsize = ENV['TEST_USED'].to_i
	print "Test mode "
      end
      puts "Size = #{fsize}"
      xfsize = fsize
      stm = Time.now
      if fsize > 0
	rbytes = 0
	sport.set_vtime 5
	sport.write("flash_read 0 #{fsize}\n")
	res = sio.expect("flash_read 0 #{fsize}\r\nReading #{fsize} bytes at 0:\r\n",1)
	if res
	  n = 0
	  rtim = 9999
	  dbuf = ''
	  loop do
	    data = sio.read(4096)
	    unless data.nil? or data.length.zero?
	      rsize = data.length
	      rbytes += rsize
	      rbytes = fsize if rbytes > fsize
	      if n % 4 == 0
		rem = fsize - rbytes
		rtim = rem*10/rbaud
		pct = 100*rbytes/fsize
		print "\rread #{rbytes} / #{fsize} %3d%% %4ds\r" % [pct,rtim]
	      end
	      n += 1
	      dbuf << data
	    else
	      delok = ((fsize - rbytes) < 256)
	      break
	    end
	  end
	  File.open(ofile, "wb") {|fh| fh.write dbuf }
	end
      else
	delok = true
      end
    end
  rescue Exception => e
    puts e.message
    puts e.backtrace.inspect
  end
end
etm = Time.now
puts

if x_erase || (delok && erase)
  puts "Erasing"
  sport.write("flash_erase\n")
  sio.expect "Done", 300
  puts "Done"
end

if xfsize > 0
  et = etm - stm
  if et > 0
    rate = xfsize / et
    puts "Got %d bytes in %.1fs %.1f b/s" % [xfsize, et, rate]
  end
end
puts "Exiting"

if defser
  sport.write("#{defser}\n")
  sleep 0.1
  sport.write "save\n"
else
  sport.write "exit\n"
end
sio.expect("Rebooting") rescue nil
