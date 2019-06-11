#!/usr/bin/ruby
require 'nokogiri'

wps=[]
ARGF.each do |l|
  if l.match(/^wp [0-9]/)
    a = l.chomp.split(' ')
    unless a[2].to_i.zero?
      act = (a[2] == '4') ? "RTH" : "WAYPOINT"
      wps << { :no => 1 + a[1].to_i, :act => act, :lat => a[3].to_i/ 1e7,
	:lon => a[4].to_i/ 1e7, :altm => ((a[5].to_i + 50)/100).to_i,
	:p1 => a[6].to_i}
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
			 'parameter2' => '0', 'paramater3' => '0'})
    end
  }
end
puts m.to_xml
