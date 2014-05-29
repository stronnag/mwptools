#!/usr/bin/ruby

require 'sequel'
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

  def build arry, outf, title=nil
    kml = KMLFile.new

    linestr=''
    title||='MWP Log'
    desc=title

    doc = {
      :name => 'Tracker',
      :styles => [
	Style.new(
		  :id => 'HeliIcon',
		  :icon_style => IconStyle.new(
					       :icon => Icon.new(
								 :href => "http://maps.google.com/mapfiles/kml/shapes/heliport.png"
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

    arry.each do |p|
      folder = Folder.new(:name => "Track #{p[:sno]}")
      p[:data].each do |el|
	coords = "#{el[:lon]},#{el[:lat]},#{el[:alt]}"
	linestr << coords << "\n"
      end

      pm = Placemark.new(:name => "Track #{p[:sno]}",
			 :description => desc,
			 :style_url => '#transBluePoly',
			 :geometry => LineString.new(
						     :extrude => true,
						     :tessellate => false,
						     :altitude_mode => 'absolute',
						     :coordinates => linestr
						     )
			 )

      folder.features << pm
      np = 0
      p[:data].each do |r|
	ptid = "# #{p[:sno]}.%03d" % np
	np += 1
	ctim = r[:stamp].gmtime.strftime("%FT%TZ")
	adesc = "#{title}<br/>Time: #{ctim}<br/>Position: #{posstrg(r[:lat],r[:lon])}<br/>Speed: #{"%.1f" % r[:spd]}m/s<br/>Course: #{"%d" % r[:cse]}deg<br/>Altitude: #{r[:alt]}m<br/>"
	coords = "#{r[:lon]},#{r[:lat]},#{r[:alt]}"
	pt = Placemark.new(:name => ptid,
			   :description => adesc,
			   :geometry => Point.new(:coordinates=> coords),
			   :style_url => '#HeliIcon'
			   )
	folder.features << pt
      end
      doc[:features] << folder
    end
    kml.objects <<  Document.new(doc)
    File.open(outf,'w') {|f| f.puts kml.render }
  end
end

if __FILE__ == $0
  require 'nokogiri'
  require 'optparse'

  def read_sql_data dburi,armed,mid=1
    arry=[]
    larmed=nil
    sect=nil
    sno = 0
    db=Sequel.connect dburi
    db[:reports].exclude(:lat => nil).filter(:mid => mid).order(:id).each do |r|
      if (armed.nil? and sect.nil?) or
	  (armed and r[:armed] != larmed and r[:armed] == true)
	sect = {:sno => sno, :data => []}
	arry << sect
	sno += 1
      end
      larmed = r[:armed]
      if armed.nil? or r[:armed]
	sect[:data] << r
      end
    end
    arry
  end

  armed=nil
  mid=1
  ARGV.options do |opt|
    opt.banner = "#{File.basename($0)} [options] [file]"
    opt.on('-a','--armed'){armed=true}
    opt.on('-m','--mission NO',Integer){|o| mid=o}
    opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
    begin
      opt.parse!
    rescue
      puts opt ; exit
    end
  end

  k = KMLBuilder.new
  arry = read_sql_data ARGV[0],armed,mid
  k.build arry, (ARGV[1]||STDOUT.fileno)
end
