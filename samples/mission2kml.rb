#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# MIT licence

require 'ruby_kml'
include KML

class KMLBuilder

  def initialize debug=nil
    @debug=debug
  end

  def pos_to_bits pos, fmt
    ds = pos*3600.0
    s=ds % 60.0
    m=(ds / 60).to_i % 60
    d=pos.to_i
    fmt % [d,m,s]
  end

  def posstrg lat,lng
    slat = (lat >= 0) ? 'N' : 'S';
    lat = lat.abs
    slng = (lng >= 0) ? 'E' : 'W';
    lng = lng.abs
    s0 = pos_to_bits(lat, "%02d:%02d:%04.1f")
    s1 = pos_to_bits(lng, "%03d:%02d:%04.1f")
    "#{s0}#{slat} #{s1}#{slng}"
  end

  def pts_from_file inf
    pos = []
    llat = llon = lalt = nil
    doc = Nokogiri::XML(open(inf))
    doc.xpath('//MISSIONITEM|//missionitem').each do |t|
      action=t['action']
      break if action == 'RTH'
      no = t['no'].to_i
      if action == "JUMP" || action == "SET_HEAD"
        lat = llat
        lon = llon
        alt = lalt
      else
        lat = t['lat'].to_f
        lon = t['lon'].to_f
        alt = t['alt'].to_i
      end
      pos << {:no => no, :lat => lat, :lon => lon, :alt => alt, :act => action}
      llat = lat
      llon = lon
      lalt = alt
      break if action == 'POSHOLD_UNLIM'
    end
    pos
  end

  def build arry, outf
    kml = KMLFile.new
    linestr=''
    title='Mission'
    desc=title
    arry.each do |el|
      if el[:act] != 'SET_POI'
	coords = "#{el[:lon]},#{el[:lat]},#{el[:alt]}"
	linestr << coords << "\n"
      end
    end

# POI http://maps.google.com/mapfiles/kml/paddle/ylw-diamond.png
# WP http://maps.google.com/mapfiles/kml/paddle/ltblu-circle.png
# Land http://maps.google.com/mapfiles/kml/paddle/pink-stars.png
# Poshold timed http://maps.google.com/mapfiles/kml/paddle/purple-circle.png
# poshold unlim http://maps.google.com/mapfiles/kml/paddle/grn-diamond.png

    doc = {
      :name => 'Tracker',
      :styles => [
	Style.new(
	  :id => 'SET_POI',
	  :icon_style => IconStyle.new(
	    :icon => Icon.new(
	      :href => "http://maps.google.com/mapfiles/kml/paddle/ylw-diamond.png"
	    )
	  )
	),
	Style.new(
	  :id => 'SET_HEAD',
	  :icon_style => IconStyle.new(
	    :icon => Icon.new(
	      :href => "http://maps.google.com/mapfiles/kml/paddle/ylw-diamond.png"
	    )
	  )
	),

	Style.new(
	  :id => 'WAYPOINT',
	  :icon_style => IconStyle.new(
	    :icon => Icon.new(
	      :href => "http://maps.google.com/mapfiles/kml/paddle/ltblu-circle.png"
	    )
	  )
	),

	Style.new(
	  :id => 'POSHOLD_UNLIM',
	  :icon_style => IconStyle.new(
	    :icon => Icon.new(
	      :href => "http://maps.google.com/mapfiles/kml/paddle/grn-diamond.png"
	    )
	  )
	),

	Style.new(
	  :id => 'POSHOLD_TIME',
	  :icon_style => IconStyle.new(
	    :icon => Icon.new(
	      :href => "http://maps.google.com/mapfiles/kml/paddle/grn-circle.png"
	    )
	  )
	),

	Style.new(
	  :id => 'JUMP',
	  :icon_style => IconStyle.new(
	    :icon => Icon.new(
	      :href => "http://maps.google.com/mapfiles/kml/paddle/purple-circle.png"
	    )
	  )
	),

	Style.new(
	  :id => 'LAND',
	  :icon_style => IconStyle.new(
	    :icon => Icon.new(
	      :href => "http://maps.google.com/mapfiles/kml/paddle/pink-stars.png"
	    )
	  )
	),


	Style.new(:id => "transBluePoly",
		  :line_style => LineStyle.new(:width => 1.5),
		  :poly_style => PolyStyle.new(:color => '7dff0000')
		 )
      ],
      :features => []
    }

    pm = Placemark.new(:name => 'Track',
                       :description => desc,
                       :style_url => '#transBluePoly',
                       :geometry => LineString.new(
                                                   :extrude => true,
                                                   :tessellate => false,
                                                   :altitude_mode => 'relativeToGround',
                                                   :coordinates => linestr
                       )
		      )

    doc[:features] << pm
    arry.each do |p|
      adesc = "#{title}<br/>Action: #{p[:act]}<br/>Position: #{posstrg(p[:lat],p[:lon])}<br/>Altitude: #{p[:alt]}m<br/>"
      coords = "#{p[:lon]},#{p[:lat]},#{p[:alt]}"
      pt = Placemark.new(:name => "WP #{p[:no]}",
			 :description => adesc,
			 :geometry => Point.new(:altitude_mode => 'relativeToGround', :coordinates=> coords),
			 :style_url => "##{p[:act]}",
			)
      doc[:features] << pt
    end
    kml.objects <<  Document.new(doc)
    File.open(outf,'w') {|f| f.puts kml.render }
  end
end

if __FILE__ == $0
  k = KMLBuilder.new
  arry = k.pts_from_file ARGV[0]
  k.build arry, (ARGV[1]||STDOUT.fileno)
end
