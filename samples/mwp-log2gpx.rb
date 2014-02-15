#!/usr/bin/ruby

require 'yajl'
require 'nokogiri'

abort "Usage: mwp_log2gpx.rb FILE\n" unless file = ARGV[0]

doc=nil
json = File.new(file, 'r')

# unashamedly 1.0, so we can have <course> and <speed>
m = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
  xml.gpx('xmlns' => 'http://www.topografix.com/GPX/1/0',
	  'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
	  'xsi:schemaLocation' =>
	  "http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd",
	  'version' => "1.0",
	  'creator' => "mwp_log2gpx") {
    xml.trk {
      xml.src "Created by mwp_log2gpx from a MWP mission log"
      xml.trkseg {
	Yajl::Parser.parse(json, {:symbolize_names => true}) do |o|
	  if o[:type] == 'raw_gps'
	    xml.trkpt('lat' => o[:lat], 'lon' => o[:lon]) {
	      xml.ele o[:alt]
	      xml.time Time.at(o[:utime]).gmtime.strftime("%FT%TZ")
	      xml.sat o[:numsat].to_s
	      xml.course o[:cse].to_s
	      xml.speed o[:spd].to_s
	      xml.cmt "Course #{o[:cse]}°, speed #{o[:spd]}m/s"
	    }
	  end
	end
      }
    }
  }
end

fn=(ARGV[1]||STDOUT.fileno)
File.open(fn,'w') {|fh| fh.puts m.to_xml}
