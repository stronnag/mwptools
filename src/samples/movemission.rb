#!/usr/bin/ruby
require 'xmlsimple'
require 'optparse'
require 'tempfile'
include Math

def ll2metres lat, lon
  x = lon * 20037508.34 / 180;
  y = log(tan((90 + lat) * PI / 360)) / (PI / 180);
  y = y * 20037508.34 / 180;
  [x, y]
end

def metres2ll x,y
  lon = x*180.0/20037508.34
  lat = y*180.0/20037508.34
  lat = (atan(E ** (lat * (PI / 180))) * 360) / PI - 90
  [lat,lon]
end

def move11 lat, lon, dx, dy
  if lat != 0 && lon !=0
    lx,ly = ll2metres lat,lon
    lx += dx
    ly += dy
    lat,lon = metres2ll lx, ly
  end
  [lat,lon]
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
blat = a[0].to_f
blon = a[1].to_f
bx,by = ll2metres blat,blon
m['mission']['missionitem'].each_with_index do |mi,j|
  lat = mi['lat'].to_f
  lon = mi['lon'].to_f
  mi['action'].upcase!
  case j
  when 0
    lx,ly = ll2metres lat,lon
    dx = bx - lx
    dy = by - ly
    lat = blat
    lon = blon
  else
    lat,lon = move11(lat, lon, dx, dy)
  end
  mi['lat'] = lat
  mi['lon'] = lon
end

lat = mx['cy'].to_f
lon = mx['cx'].to_f
mx['cy'], mx['cx'] = move11(lat, lon, dx, dy)

lat = mx['home-y'].to_f
lon = mx['home-x'].to_f
mx['home-y'], mx['home-x'] = move11(lat, lon, dx, dy)

xml = XmlSimple.xml_out(m, { 'KeepRoot' => true })
if outfile.nil?
  puts xml
else
  IO.write(outfile, xml)
end
