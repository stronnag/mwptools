#!/usr/bin/ruby

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
    fn = File.join(dir,"#{base}_#{n}#{ext}")
    puts fn
    File.open(fn,"wb") do |f|
	f.write 'H Product:Blackbox flight data recorder by Nicholas Sherlock'
	f.write(r)
      end
    n += 1
  end
end
