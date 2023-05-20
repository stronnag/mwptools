#!/usr/bin/ruby
require 'xmlsimple'
require 'optparse'
require 'tempfile'

def read_cs_line str
  bp = str.split
  [bp[0].to_f, bp[1].to_f]
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

cs2cs = system "cs2cs 2> /dev/null"
if !cs2cs or rebase.nil?
  abort "no rebase location or 'cs2cs' not found"
end

dx = nil
dy = nil
nx = nil
ny = nil

doc=IO.read(ARGV[0] || STDIN)
doc.downcase!
m=XmlSimple.xml_in(doc, {'ForceArray' => false, 'KeepRoot' => true})
mx = nil
if m['mission']['mwp']
  mx = m['mission']['mwp']
elsif  m['mission']['meta']
  mx = m['mission']['meta']
end

have_cxy = false
have_hxy = false

llfile = nil
if !rebase.nil?
  fh = Tempfile.new("mm-ll")
  begin
    llfile = fh.path
    a=rebase.split(/,/)
    lat = a[0].to_f
    lon = a[1].to_f
    fh.puts "#{lat} #{lon} 0 #newbase"
    m['mission']['missionitem'].each_with_index do |mi,j|
      lat = mi['lat'].to_f
      lon = mi['lon'].to_f
      if lat != 0 && lon != 0
        fh.puts "#{lat} #{lon} 0 #wp{j+1}"
      end
    end
    unless mx.nil?
      lat = mx['cy'].to_f
      lon = mx['cx'].to_f
      if lat != 0 && lon != 0
        have_cxy = true
        fh.puts "#{lat} #{lon} 0 #cx"
      end
      lat = mx['home-y'].to_f
      lon = mx['home-x'].to_f
      if lat != 0 && lon != 0
        have_hxy = true
        fh.puts "#{lat} #{lon} 0 #hx"
      end
    end
  ensure
    fh.close
  end
end

fh = Tempfile.new('mm-proj')
projfile = fh.path
fh.close

%x|cs2cs -f "%f" EPSG:4326 EPSG:3857 < #{llfile} > #{projfile}|

arry = IO.readlines(projfile)

File.open(projfile, "w") do |fh|
  fh.puts "#{nx} #{ny}"
  nx = nil
  ny = nil
  dx =nil
  dy = nil
  arry.each_with_index do |a,j|
    case j
    when 0
      nx,ny = read_cs_line a
    when 1
      lx,ly = read_cs_line a # pt 0
      dx = nx - lx
      dy = ny - ly
    else
      lx,ly = read_cs_line a
      px = lx + dx
      py = ly + dy
      fh.puts "#{px} #{py}"
    end
  end
end

%x|cs2cs -f "%f" EPSG:3857 EPSG:4326 > #{llfile} < #{projfile}|

arry = IO.readlines(llfile)
n = 0
m['mission']['missionitem'].each_with_index do |mi,j|
  mi['action'].upcase!
  lat = mi['lat'].to_f
  lon = mi['lon'].to_f
  if lat != 0 && lon != 0
    lat,lon = read_cs_line arry[n]
    mi['lat'] = lat
    mi['lon'] = lon
    n += 1
  end
end
if have_cxy
  mx['cy'], mx['cx'] = read_cs_line arry[n]
  n += 1
end
if have_hxy
  mx['home-y'], mx['home-x'] = read_cs_line arry[n]
end

xml = XmlSimple.xml_out(m, { 'KeepRoot' => true })
if outfile.nil?
  puts xml
else
  IO.write(outfile, xml)
end
