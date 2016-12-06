#!/usr/bin/ruby
# -*- coding: utf-8 -*-

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
    tdist = 0
    doc = Nokogiri::XML(open(fn))
    doc.xpath('//MISSIONITEM|//missionitem').each do |t|
      action=t['action']
      break if action == 'RTH'
      next if action == 'SET_POI'
      no = t['no'].to_i
      lat = t['lat'].to_f
      lon = t['lon'].to_f
      alt = t['alt'].to_i
      md = 0
      if lx and ly
	c,d = Geocalc.csedist ly,lx,lat,lon
	md = d*1852
	dc << {:cse => c, :dist => md}
      end
      lx = lon
      ly = lat
      tdist += md
      ipos << {:no => no, :lat => lat, :lon => lon, :alt => alt, :act => action,
	:p1 => t['parameter1'], :p2 => t['parameter2'], :p3 => t['parameter3'],
	:tdist => tdist}
      break if action == 'POSHOLD_UNLIM'
    end
    pos=[]
    ipos.each do |p|
      d = dc.shift
      pos << ((d) ? p.merge(d) : p)
    end
    pos
  end

  def to_info pos, fn=nil
    File.open(fn,"w") do |fh|
      fh.puts %w/No Act Lat Lon Alt P1 P2 P3 Course Leg\ (m) Total\ (m)/.join("\t")
      pos.each do |p|
	cse =  p[:cse] ? "%.1f" % p[:cse] : nil
	dist = p[:cse] ? "%.0f" % p[:dist] : nil
	md = "%.0f" % p[:tdist]
	fh.puts [p[:no], p[:act], p[:lat], p[:lon], p[:alt], p[:p1], p[:p2],
	p[:p3],cse, dist, md].join("\t")
      end
    end
  end

end

g = MReader.new
pos = g.read ARGV[0]
g.to_info pos, (ARGV[1]||STDOUT.fileno)
