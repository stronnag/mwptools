#!/usr/bin/ruby

require 'yajl'
require 'nokogiri'
require 'optparse'

armed=nil
aval=nil
sno=0

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-a','--armed'){armed=true}
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
Yajl::Parser.parse(json, {:symbolize_names => true}) do |o|
  if o[:type] == 'raw_gps'
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
end
fn=(ARGV[1]||STDOUT.fileno)
File.open(fn,'w') {|fh| fh.puts doc.to_xml}
