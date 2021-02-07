#!/usr/bin/ruby
require 'xmlsimple'
require 'optparse'

cli = true
ARGV.options do |opt|
  opt.on('-p','--pretty'){cli=false}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

m=XmlSimple.xml_in((ARGV[0] || STDIN), {'ForceArray' => false, 'KeepRoot' => false})
last = m['missionitem'].size - 1
m['missionitem'].each_with_index do |i,n|
  xlat = "%.6f" % i['lat'].to_f
  xlon = "%.6f" % i['lon'].to_f
  lat = (i['lat'].to_f*1e7).to_i
  lon = (i['lon'].to_f*1e7).to_i
  alt = i['alt'].to_i*100
  p1 = i['parameter1'].to_i
  p2 = i['parameter2'].to_i
  p3 = i['parameter3'].to_i

  act = case i['action']
	when 'WAYPOINT'
	  1
	when 'POSHOLD_TIME'
	  3
	when 'RTH'
	  4
	when 'SET_POI'
	  5
	when 'JUMP'
	  6
	when 'SET_HEAD'
	  7
	when 'LAND'
	  8
	else
	  0
	end
  flag = (n == last) ? 165 : 0
  if cli
    if act == 6
       p1 -= 1
    end
    puts ['wp', n, act, lat, lon, alt, p1, p2, p3, flag].join(' ')
  else
    flag = "%d" % flag unless flag == 0
    puts [n+1, i['action'],xlat,xlon,i['alt'],
      p1,p2,p3, flag].join(' ')
end
end
