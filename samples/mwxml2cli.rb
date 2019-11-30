#!/usr/bin/ruby
require 'xmlsimple'
m=XmlSimple.xml_in((ARGV[0] || STDIN), {'ForceArray' => false, 'KeepRoot' => false, 'AttrToSymbol' => true, 'KeyToSymbol' => true})
last = m[:missionitem].size - 1
puts "# mwxml2cli.rb"
puts "# convert MW XML misison file to iNav CLI"
m[:missionitem].each_with_index do |i,n|
  lat = (i[:lat].to_f*1e7).to_i
  lon = (i[:lon].to_f*1e7).to_i
  alt = i[:alt].to_i*100
  act = i[:action] == 'WAYPOINT' ?  1 : 4
  flag = (n == last) ? 165 : 0
  puts ['wp', n, act, lat, lon, alt, i[:parameter1], flag].join(' ')
end
