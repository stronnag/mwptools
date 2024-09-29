#!/usr/bin/ruby
require 'nokogiri'

wps=[]
ARGF.each do |l|
  if l.match(/^wp [0-9]/)
    a = l.chomp.split(' ')
    unless a[2].to_i.zero?
      act = case a[2]
	    when '3'
	      'POSHOLD_TIME'
	    when '4'
	      'RTH'
	    when '6'
	      'JUMP'
	    when '8'
	      'LAND'
	    else
	      'WAYPOINT'
	    end

      p1 = a[6].to_i
      if a[2] == '6'
	p1 += 1
      end
      wps << { :no => 1 + a[1].to_i, :act => act, :lat => a[3].to_i/ 1e7,
	:lon => a[4].to_i/ 1e7, :altm => ((a[5].to_i + 50)/100).to_i,
	:p1 => p1, :p2 => (a[7]||0).to_i, :p3 => (a[8]||0).to_i }
    end
  end
end

dt = Time.now.strftime("%FT%T%z")

m = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
  xml.mission {
    xml.mwp ({'generator' => "mwptools/cli2mwxml", 'save-date' => dt})
    wps.each do |w|
      xml.missionitem ({'no' => w[:no], 'action' => w[:act],
		       'lat' => w[:lat], 'lon' => w[:lon],
		       'alt' => w[:altm], 'parameter1' => w[:p1],
			 'parameter2' => w[:p2], 'paramater3' => w[:p3]})
    end
  }
end
puts m.to_xml
