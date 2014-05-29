#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'sequel'
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

abort "Usage: mwp_log2x.rb FILE\n" unless file = ARGV[0]

doc=nil
paths = read_sql_data ARGV[0], armed,mid

doc = Nokogiri::XML::Document.new
doc.encoding = 'utf-8'
m =  doc.create_element('gpx', :version => '1.1', :creator => "mwp_log2gpx")
m.add_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
m.add_namespace(nil, 'http://www.topografix.com/GPX/1/1')
m.add_namespace('gpxx', "http://www.garmin.com/xmlschemas/GpxExtensions/v3")
m.add_namespace('gpxtpx', "http://www.garmin.com/xmlschemas/TrackPointExtension/v2")
m['xsi:schemaLocation']="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
doc.add_child(m)

paths.each do |p|
  m0 = m.add_child(doc.create_element('trk'))
  m0.add_child(doc.create_element('name', "mwplog_#{p[:sno]}"))
  m1 = m0.add_child(doc.create_element('trkseg'))
  p[:data].each do |r|
    m2 = m1.add_child(doc.create_element('trkpt',
					 :lat => r[:lat], :lon => r[:lon]))
    m2.add_child(doc.create_element('ele',r[:alt].to_s))
    m2.add_child(doc.create_element('time',
				    r[:stamp].gmtime.strftime("%FT%TZ")))
    m2.add_child(doc.create_element('cmt',
				    "Course #{r[:cse]}°, speed #{r[:spd]}m/s"))
    m2.add_child(doc.create_element('sat', r[:numsat].to_s))
    m3 = m2.add_child(doc.create_element('extensions'))
    m4 = m3.add_child(doc.create_element('gpxtpx:TrackPointExtension'))
    m4.add_child(doc.create_element('gpxtpx:course', r[:cse].to_s))
    m4.add_child(doc.create_element('gpxtpx:speed', r[:spd].to_s))
  end
end
fn=(ARGV[1]||STDOUT.fileno)
File.open(fn,'w') {|fh| fh.puts doc.to_xml}
