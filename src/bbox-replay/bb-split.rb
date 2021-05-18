#!/usr/bin/ruby

require 'stringio'
require 'time'

# Split multiple logs into individual files

ext = File.extname(ARGV[0])
dir = File.dirname(ARGV[0])
base = File.basename(ARGV[0], ext)

a=IO.binread(ARGV[0])
res = a.split('H Product:Blackbox flight data recorder by Nicholas Sherlock')
if res.length > 1
  res.shift
  n = 1
  res.each do |r|
    s = StringIO.new r
    dt=nil
    i = 0
    s.each do |l|
      i+=1
      if m=l.match(/^H Log start datetime:(\S+)$/)
	dt = m[1]
	break
      end
      break if i >= 60
    end
    id = ''
    if dt
      t = Time.parse dt
      id=t.strftime("_%F_%H%M%S")
    end
    fn = File.join(dir,"#{base}_#{n}#{id}#{ext}")
    puts fn
    File.open(fn,"wb") do |f|
	f.write 'H Product:Blackbox flight data recorder by Nicholas Sherlock'
	f.write(r)
      end
    n += 1
  end
end
