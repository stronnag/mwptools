#!/usr/bin/ruby
require 'xmlsimple'
require 'optparse'
require 'tempfile'
require_relative 'poscalc'

include Math

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
