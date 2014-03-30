#!/usr/bin/ruby

require 'nokogiri'
include Math

module Geocalc
  RAD = 0.017453292

  def Geocalc.d2r d
    private
    d*RAD
  end

  def Geocalc.r2d r
    private
    r/RAD
  end

  def Geocalc.r2nm r
    private
    ((180*60)/PI)*r
  end

  def Geocalc.csedist lat1,lon1,lat2,lon2
    lat1 = d2r(lat1)
    lon1 = d2r(lon1)
    lat2 = d2r(lat2)
    lon2 = d2r(lon2)
    d=2.0*asin(sqrt((sin((lat1-lat2)/2.0))**2 +
		    cos(lat1)*cos(lat2)*(sin((lon2-lon1)/2.0))**2))
    d = r2nm(d)
    cse =  (atan2(sin(lon2-lon1)*cos(lat2),
		 cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1))) % (2.0*PI)
    cse = r2d(cse)
    [cse,d]
  end
end

class MReader
  def read fn
    ipos = []
    dc=[]
    lx=ly=nil
    doc = Nokogiri::XML(open(fn))
    doc.xpath('//missionitem').each do |t|
      action=t['action']
      break if action == 'RTH'
      next if action == 'SET_POI'
      no = t['no'].to_i
      lat = t['lat'].to_f
      lon = t['lon'].to_f
      alt = t['alt'].to_i
      if lx and ly
	c,d = Geocalc.csedist ly,lx,lat,lon
	dc << {:cse => c, :dist => d*1852}
      end
      lx = lon
      ly = lat
      ipos << {:no => no, :lat => lat, :lon => lon, :alt => alt, :act => action}
      break if action == 'POSHOLD_UNLIM'
    end
    pos=[]
    ipos.each do |p|
      d = dc.shift
      pos << ((d) ? p.merge(d) : p)
    end
    pos
  end

  def to_gpx pos, fn=nil
    doc = Nokogiri::XML::Document.new
    doc.encoding = 'utf-8'
    gpx = Nokogiri::XML::Node.new 'gpx',doc
    gpx['xmlns:xsi'] = 'http://www.w3.org/2001/XMLSchema-instance'
    gpx['xmlns'] = 'http://www.topografix.com/GPX/1/0'
    gpx['xmlns:mwpgpx'] = 'http://daria.co.uk/GPX/MWP/1/0'
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
      if p[:dist] and p[:cse]
	xe = Nokogiri::XML::Node.new 'extensions', doc
	xe.add_child(Nokogiri::XML::Node.new('mwpgpx:distance', doc) << ("%.1f" % p[:dist]) )
	xe.add_child(Nokogiri::XML::Node.new('mwpgpx:bearing', doc) << ("%.1f" % p[:cse]) )
	tp.add_child(xe)
      end
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
