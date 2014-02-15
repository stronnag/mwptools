#!/usr/bin/ruby

require 'nokogiri'

class MReader
  def read fn
    pos = []
    doc = Nokogiri::XML(open(fn))
    doc.xpath('//missionitem').each do |t|
      action=t['action']
      break if action == 'RTH'
      next if action == 'SET_POI'
      no = t['no'].to_i
      lat = t['lat'].to_f
      lon = t['lon'].to_f
      alt = t['alt'].to_i
      pos << {:no => no, :lat => lat, :lon => lon, :alt => alt, :act => action}
      break if action == 'POSHOLD_UNLIM'
    end
    pos
  end

  def to_gpx pos, fn=nil
    doc = Nokogiri::XML::Document.new
    doc.encoding = 'utf-8'
    gpx = Nokogiri::XML::Node.new 'gpx',doc
    gpx['xmlns:xsi'] = 'http://www.w3.org/2001/XMLSchema-instance'
    gpx['xmlns'] = 'http://www.topografix.com/GPX/1/0'
    gpx['version']="1.0"
    gpx['creator']="mission2gpx"
    doc.add_child(gpx)
    t = Nokogiri::XML::Node.new 'trk',doc
    gpx.add_child(t)
    t.add_child(Nokogiri::XML::Node.new('name', doc) << 'MW Mission')
    s = Nokogiri::XML::Node.new 'trkseg', doc
    t.add_child(s)
    pos.each do |p|
      tp = Nokogiri::XML::Node.new 'trkpt', doc
      tp['lat'] = p[:lat].to_s
      tp['lon'] = p[:lon].to_s
      s.add_child(tp)
      tp.add_child(Nokogiri::XML::Node.new('name', doc) << ("WP%03d" % p[:no]))
      tp.add_child(Nokogiri::XML::Node.new('ele', doc) << p[:alt].to_s)
    end
    File.open(fn,"w") {|fh| fh.puts doc.to_xml}
  end

end

g = MReader.new
pos = g.read ARGV[0]
g.to_gpx pos, (ARGV[1]||STDOUT.fileno)
