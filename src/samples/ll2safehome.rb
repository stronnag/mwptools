#!/usr/bin/ruby

if ARGV.size == 2
  lat = ARGV[0].to_f
  lon = ARGV[1].to_f
  ilat = (lat * 1e7).to_i
  ilon = (lon * 1e7).to_i
  puts "safehome <N> 1 #{ilat} #{ilon}"
end
