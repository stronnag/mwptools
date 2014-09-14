#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'yajl'
require 'optparse'
require 'ruby_kml'
include KML

class KMLBuilder
  attr_accessor :armed, :fix, :nsats

  def initialize debug=nil
    @debug=debug
    @armed=nil
    @fix=nil
    @nsats=nil
  end

  def pos_to_bits pos, fmt
    ds = pos*3600.0
    s=ds % 60.0
    m=(ds / 60).to_i % 60
    d=pos.to_i
    fmt % [d,m,s]
  end

  def posstrg lat,lng
    slat = (lat >= 0) ? 'N' : 'S'
    lat = lat.abs
    slng = (lng >= 0) ? 'E' : 'W'
    lng = lng.abs
    s0 = pos_to_bits(lat, "%02d:%02d:%04.1f")
    s1 = pos_to_bits(lng, "%03d:%02d:%04.1f")
    "#{s0}#{slat} #{s1}#{slng}"
  end

  def pts_from_file inf
    arry = []
    astat = nil
    json = File.new(inf)
    Yajl::Parser.parse(json, {:symbolize_names => true}) do |o|
      # for ancient Ubuntu and friends
      keys = o.keys
      keys.each do |k|
	if k.class == String
	  o[k.to_sym] = o[k]
	  o.delete(k)
	end
      end
      if o[:type] == 'armed'
	astat = o[:armed]
      end
      if o[:type] == 'raw_gps'
	next if @armed and astat == :false
	next if @fix and (o[:fix].nil? or o[:fix] < 1)
	next if @nsats and (o[:numsat].nil? or o[:numsat] < @nsats)
	arry << {:lat => o[:lat],  :lon => o[:lon], :alt => o[:alt],
	  :utime => o[:utime], :spd => o[:spd], :cse => o[:cse]}
      end
    end
    arry
  end

  def build arry, outf, title=nil
    kml = KMLFile.new

    linestr=''
    title||='MWP Log'
    desc=title

    STDERR.puts "selected #{arry.size} records"
    arry.each do |el|
      coords = "#{el[:lon]},#{el[:lat]},#{el[:alt]}"
      linestr << coords << "\n"
    end

    doc = {
      :name => 'Tracker',
      :styles => [],
      :features => []
    }

    0.upto(15).each do |j|
      doc[:styles] << 	Style.new(
				  :id => "mwpIcon_#{j}",
				  :icon_style =>
				  IconStyle.new(
						:icon =>
						Icon.new(
							 :href => "http://earth.google.com/images/kml-icons/track-directional/track-#{j}.png"


					 )
				)
		  )
    end

    doc[:styles] <<
      Style.new(:id => "transBluePoly",
		:line_style => LineStyle.new(:width => 1.5),
		:poly_style => PolyStyle.new(:color => '7dff0000')
		)

    pm = Placemark.new(:name => 'Track',
                       :description => desc,
                       :style_url => '#transBluePoly',
                       :geometry => LineString.new(
                                                   :extrude => true,
                                                   :tessellate => false,
                                                   :altitude_mode => 'absolute',
                                                   :coordinates => linestr
                                                   )
		       )

    doc[:features] << pm
    arry.each_with_index do |p,k|
      ctim = Time.at(p[:utime]).gmtime.strftime("%FT%TZ")
      adesc = "#{title}<br/>Time: #{ctim}<br/>Position: #{posstrg(p[:lat],p[:lon])}<br/>Speed: #{"%.1f" % p[:spd]}m/s<br/>Course: #{"%d" % p[:cse]}deg<br/>Altitude: #{p[:alt]}m<br/>"
      coords = "#{p[:lon]},#{p[:lat]},#{p[:alt]}"

      cdx = p[:cse]/22.5
      idx = ((cdx+0.5).to_i) % 16;

      pt = Placemark.new(:name => ("mwp_%04d" % k),
			 :description => adesc,
			 :style_url => "#mwpIcon_#{idx}",
			 :geometry => Point.new(:coordinates=> coords),
			 )
      doc[:features] << pt
    end

    kml.objects <<  Document.new(doc)
    File.open(outf,'w') {|f| f.puts kml.render }
  end
end

if __FILE__ == $0
  k = KMLBuilder.new
  ARGV.options do |opt|
    opt.banner = "#{File.basename($0)} [options] [file]"
    opt.on('-a','--armed'){k.armed=true}
    opt.on('-f','--fix'){k.fix=true}
    opt.on('-n','--numsats NSATS',Integer){|o|k.nsats=o}
    opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
    begin
      opt.parse!
    rescue
      puts opt ; exit
    end
  end
  arry = k.pts_from_file ARGV[0]
  k.build arry, (ARGV[1]||STDOUT.fileno)
end
