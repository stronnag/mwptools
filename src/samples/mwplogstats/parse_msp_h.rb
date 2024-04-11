#!/usr/bin/ruby

# Build golang map from C header files
# ./parse_msp_h.rb ~/Projects/fc/inav/src/main/msp/msp*protocol*.h

puts "mspnamemap = map[uint16]string{"
h = {}
ARGF.each do |l|
  if l.match(/^#define\s+MSP(_|2_)/)
    a=l.split(' ')
    next unless a[2][0] >= '0' && a[2][0] <= '9'
    k = Integer(a[2])
    next if k == 0
    h[k] = a[1]
  end
end
h = h.sort_by {|k, v| k}.to_h
h.each do |k,v|
  ks = (k < 4096) ? "%d" % k : "0x%x" % k
  puts "  #{ks}: \"#{v}\","
end
puts "}"
