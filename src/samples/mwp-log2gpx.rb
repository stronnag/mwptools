#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# MIT licence

require 'yajl'
require 'nokogiri'
require 'optparse'

armed=nil
fix=nil
nsats=nil
sno=0

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-a','--armed'){armed=true}
  opt.on('-f','--fix'){fix=true}
  opt.on('-n','--numsats NSATS',Integer){|o|nsats=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

abort "Usage: mwp_log2gpx.rb FILE\n" unless file = ARGV[0]

doc=nil
json = File.new(file, 'r')

# unashamedly 1.0, so we can have <course> and <speed>
doc = Nokogiri::XML::Document.new
doc.encoding = 'utf-8'
m =  doc.create_element('gpx', :version => '1.0', :creator => "mwp_log2gpx")
m.add_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
m.add_namespace(nil, 'http://www.topografix.com/GPX/1/0')
m['xsi:schemaLocation']="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd"
doc.add_child(m)
m0 = m.add_child(doc.create_element('trk'))
m0.add_child(doc.create_element('src',
				"Created by mwp_log2gpx from a MWP mission log"))
m0.add_child(doc.create_element('name', "mwplog_#{sno}"))
sno += 1
m1 = m0.add_child(doc.create_element('trkseg'))

astat = nil

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
    next if armed and astat == :false
    next if fix and (o[:fix].nil? or o[:fix] < 1)
    next if nsats and (o[:numsat].nil? or o[:numsat] < nsats)

    m2 = m1.add_child(doc.create_element('trkpt',
					 :lat => o[:lat], :lon => o[:lon]))
    m2.add_child(doc.create_element('ele',o[:alt].to_s))
    m2.add_child(doc.create_element('time',
				    Time.at(o[:utime]).gmtime.strftime("%FT%TZ")))
    m2.add_child(doc.create_element('sat', o[:numsat].to_s))
    m2.add_child(doc.create_element('course', o[:cse].to_s))
    m2.add_child(doc.create_element('speed', o[:spd].to_s))
    m2.add_child(doc.create_element('cmt',
				    "Course #{o[:cse]}°, speed #{o[:spd]}m/s"))
  end

  if o[:type] == "mavlink_gps_raw_int"
    next if armed and astat == :false
    next if fix and (o[:fix_type].nil? or o[:fix_type] < 2)
    next if nsats and (o[:satellites_visible].nil? or o[:satellites_visible] < nsats)

    m2 = m1.add_child(doc.create_element('trkpt',
					 :lat => o[:lat]/10000000.0, :lon => o[:lon]/10000000.0))
    m2.add_child(doc.create_element('ele',(o[:alt]/1000.0).to_s))
    m2.add_child(doc.create_element('time',
				    Time.at(o[:utime]).gmtime.strftime("%FT%TZ")))
    m2.add_child(doc.create_element('sat', o[:satellites_visible].to_s))
    cog = o[:cog]/100.0
    m2.add_child(doc.create_element('course', cog.to_s))
    m2.add_child(doc.create_element('speed', o[:vel].to_s))
    m2.add_child(doc.create_element('cmt',
				    "Course #{cog}°, speed #{o[:vel]}m/s"))
  end
end
fn=(ARGV[1]||STDOUT.fileno)
File.open(fn,'w') {|fh| fh.puts doc.to_xml}
