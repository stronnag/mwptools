#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# MIT licence

require 'xmlsimple'
require 'optparse'
require 'tempfile'
include Math

module Poscalc
  RAD = 0.017453292

  def Poscalc.d2r d
    d*RAD
  end

  def Poscalc.r2d r
    r/RAD
  end

  def Poscalc.nm2r nm
    (PI/(180*60))*nm
  end

  def Poscalc.r2nm r
    ((180*60)/PI)*r
  end

  def Poscalc.csedist lat1,lon1,lat2,lon2
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

  def Poscalc.posit lat1, lon1, cse, dist
    tc = d2r(cse)
    rlat1= d2r(lat1)
    rdist = nm2r(dist)
    lat = asin(sin(rlat1)*cos(rdist)+cos(rlat1)* sin(rdist)*cos(tc))
    dlon = atan2(sin(tc)*sin(rdist)*cos(rlat1),
                 cos(rdist)-sin(rlat1)*sin(lat))
    long = ((PI + d2r(lon1) + dlon) % (2 * PI)) - PI
    lat=r2d(lat)
    long = r2d(long)
    [lat, long]
  end
end

outfile=nil
rebase=nil
ARGV.options do |opt|
  opt.on('-r','--rebase=TO') {|o| rebase=o}
  opt.on('-o','--output=FILE') {|o| outfile=o}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

if rebase.nil?
  abort "no rebase location"
end

dx = nil
dy = nil

doc=IO.read(ARGV[0] || STDIN)
doc.downcase!
m=XmlSimple.xml_in(doc, {'ForceArray' => false, 'KeepRoot' => true})
mx = nil
if m['mission']['mwp']
  mx = m['mission']['mwp']
elsif  m['mission']['meta']
  mx = m['mission']['meta']
end

a=rebase.split(/,/)
tolat = a[0].to_f
tolon = a[1].to_f

blat = mx['home-y'].to_f
blon = mx['home-x'].to_f
if blat == 0.0  && blon == 0.0
  blat = m['mission']['missionitem'][0]['lat'].to_f
  blon = m['mission']['missionitem'][0]['lon'].to_f
end

m['mission']['missionitem'].each_with_index do |mi,j|
  lat = mi['lat'].to_f
  lon = mi['lon'].to_f
  mi['action'].upcase!
  if !(mi['action'] == "RTH" || mi['action'] == "SET_HEAD" || mi['action'] == "JUMP")
    c, d = Poscalc.csedist(blat, blon, lat, lon)
    lat, lon = Poscalc.posit(tolat, tolon, c, d)
    mi['lat'] = lat
    mi['lon'] = lon
  end
end

lat = mx['cy'].to_f
lon = mx['cx'].to_f
c, d = Poscalc.csedist(blat, blon, lat, lon)
mx['cy'], mx['cx'] = Poscalc.posit(tolat, tolon, c, d)

mx['home-y'] = tolat
mx['home-x'] = tolon

xml = XmlSimple.xml_out(m, { 'KeepRoot' => true })
if outfile.nil?
  puts xml
else
  IO.write(outfile, xml)
end
