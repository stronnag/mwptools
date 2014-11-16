#!/usr/bin/ruby
require 'optparse'
#require 'ap'
require 'open-uri'
require 'fileutils'
require 'nokogiri'

# Tile cache seeder. Requires (inter alia), either a mission file or
# upper left, lower right latitude and longitude e.g. -u 50.9,-1.53

class Fixnum
  def bin_str level
    self.to_s(2).rjust(level, "0")
  end
end

def quadkey level, x, y
  x_chars = x.bin_str(level).split ""
  y_chars = y.bin_str(level).split ""
  y_chars.zip(x_chars).flatten.join("").to_i(2).to_s(4).rjust(level, "0")
end

def get_tile_number(lat_deg, lng_deg, zoom)
  lat_rad = lat_deg/180 * Math::PI
  n = 2.0 ** zoom
  x = ((lng_deg + 180.0) / 360.0 * n).to_i
  y = ((1.0 - Math::log(Math::tan(lat_rad) +
			(1 / Math::cos(lat_rad))) / Math::PI) / 2.0 * n).to_i
  {:x => x, :y =>y}
end

def get_lat_lng_for_number(xtile, ytile, zoom)
 n = 2.0 ** zoom
 lon_deg = xtile / n * 360.0 - 180.0
 lat_rad = Math::atan(Math::sinh(Math::PI * (1 - 2 * ytile / n)))
 lat_deg = 180.0 * (lat_rad / Math::PI)
 {:lat_deg => lat_deg, :lng_deg => lon_deg}
end

def parse_mission_file mf
  lr=[]
  ul=[]
  minx = 999
  miny = 999
  maxx = -999
  maxy = -999
  begin
    doc = Nokogiri::XML(open(mf))
    doc.xpath('//MISSIONITEM').each do |t|
      action=t['action']
      break if action == 'RTH'
      next if action == 'SET_POI'
      lat = t['lat'].to_f
      lon = t['lon'].to_f
      miny = lat if lat < miny
      maxy = lat if lat > maxy
      minx = lon if lon < minx
      maxx = lon if lon > maxx
      break if action == 'POSHOLD_UNLIM'
    end
    ul[0] = maxy
    lr[0] = miny
    ul[1] = minx
    lr[1] = maxx
  rescue
  end
  [ul,lr]
end

uls=nil
lrs=nil
uri=nil
basedir=File.join(ENV['HOME'],".cache/champlain")
baseid=nil
zooms=nil
mf = nil

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options]"
  opt.on('-l','--upper-left=LATLON'){|o|uls=o}
  opt.on('-r','--lower-right=LATLON'){|o|lrs=o}
  opt.on('-m','--mission-file=FILE') {|o|mf=o}
  opt.on('-u','--uri=URI'){|o|uri=o}
  opt.on('-i','--id=ID'){|o|baseid=o}
  opt.on('-z','--zoom=ZOOMS'){|o|zooms=o}
  opt.on('-?', "--help", "Show this message") {puts opt; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

abort 'Not enough parameters' unless ((mf or (uls and lrs)) and uri and baseid and zooms)

ul=lr=nil
zoom = zooms.split('-')
dir = File.join(basedir,baseid)
minz = zoom[0].to_i
maxz = zoom[-1].to_i
if mf
  ul,lr = parse_mission_file mf
else
  ul=uls.split(',')
  lr=lrs.split(',')
  lr.map! {|m| m.to_f}
  ul.map! {|m| m.to_f}
end
abort 'invalid pos' unless ul.size == 2 and lr.size == 2

FileUtils.mkdir_p(dir) unless File.exist?(dir)

inc = 0
gets=[]
xnt=0
maxz.downto(minz).each do |z|
  mint = get_tile_number(ul[0], ul[1], z)
  maxt = get_tile_number(lr[0], lr[1], z)
  mint[:x] -= inc
  mint[:y] -= inc
  maxt[:x] += inc
  maxt[:y] += inc
  inc += 1
  gets << {:z => z, :sx => mint[:x], :sy => mint[:y], :ex => maxt[:x], :ey => maxt[:y]}
  nr =  1 + maxt[:x] -  mint[:x]
  nc =  1 + maxt[:y] -  mint[:y]
  nt = nr * nc
  xnt += nt
end

now = Time.now
gets.each do |m|
  sz = m[:z].to_s
  fn0 = File.join(dir,sz)
  Dir.mkdir(fn0) unless File.exist?(fn0)
  m[:sx].upto(m[:ex]).each do |tx|
    sx = tx.to_s
    fn = File.join(fn0,sx)
    Dir.mkdir(fn) unless File.exist?(fn)
    m[:sy].upto(m[:ey]).each do |ty|
      sy = ty.to_s
      case uri
      when /\#Q\#/
	q =  quadkey m[:z],tx,ty
	u = uri.gsub('#Q#',q)
      else
	u = uri.gsub('#Z#',sz)
	u.gsub!('#X#',sx)
	if uri.match('#TMSY#')
	  ymax = (1 << m[:z])
	  sy = (ymax - m[:y] - 1).to_s
	  u.gsub!('#TMSY#',sy)
	else
	  u.gsub!('#Y#',sy)
	end
      end
      ofn = File.join(fn,"#{sy}.png")
      needed = true
      if File.exist?(ofn)
	fa = (now - File.stat(ofn).mtime).to_i / 86400
	needed = (fa > 30)
	puts "skip #{ofn}" unless needed
      end
      if needed
	puts "get #{u} => #{ofn}"
	open(u) do |f|
	  a=f.read
	  File.open(ofn,'w') {|of| of.write(a)}
	end
      end
    end
  end
end
