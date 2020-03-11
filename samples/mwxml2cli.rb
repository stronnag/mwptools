#!/usr/bin/ruby
require 'xmlsimple'

cli=(ENV['DUMP'] == nil)

m=XmlSimple.xml_in((ARGV[0] || STDIN), {'ForceArray' => false, 'KeepRoot' => false})
last = m['missionitem'].size - 1
m['missionitem'].each_with_index do |i,n|
  xlat = "%.6f" % i['lat'].to_f
  xlon = "%.6f" % i['lon'].to_f
  lat = (i['lat'].to_f*1e7).to_i
  lon = (i['lon'].to_f*1e7).to_i
  alt = i['alt'].to_i*100
  act = case i['action']
	when 'WAYPOINT'
	  1
	when 'POSHOLD_TIME'
	  3
	when 'RTH'
	  4
	when 'JUMP'
	  6
	when 'LAND'
	  8
	else
	  0
	end
  flag = (n == last) ? 165 : 0
  if cli
    puts ['wp', act, lat, lon, alt, i['parameter1'], flag].join(' ')
  else
    flag = "0x%x" % flag unless flag == 0
    puts [n+1, i['action'],xlat,xlon,i['alt'],
      i['parameter1'],i['parameter2'],i['parameter3'], flag].join(' ')
end
end
