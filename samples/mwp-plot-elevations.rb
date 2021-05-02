#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# MIT licence

require "net/http"
require 'nokogiri'
require 'json'
require 'optparse'
require 'tmpdir'
require "base64"

include Math

SANITY=100

module Geocalc
  RAD = 0.017453292

  def Geocalc.d2r d
    d*RAD
  end

  def Geocalc.r2d r
    r/RAD
  end

  def Geocalc.r2nm r
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

  BKEY="QWwxYnFHYU5vZGVOQTcxYmxlSldmakZ2VzdmQXBqSk9vaE1TWjJfSjBIcGd0NE1HZExJWURiZ3BnQ1piWjF4QQ=="


  def read_config
    cfile=nil
    [".elev-plot.rc", File.join(ENV['HOME'],".config/mwp/elev-plot"), ".elev-plot.rc",
      File.join(ENV['HOME'])].each do |f|
      if File.exist? f
	cfile = f
	break
      end
    end
    unless cfile.nil?
      puts "reading options from #{cfile}"
      File.open(cfile,'r') do |f|
	f.each do |l|
	  l.chomp!
	  next if l.empty? or l.match(/^\s*#/)
	  a = l.split('=')
	  if a.size == 2
	    case a[0]
	    when /^home/
	      @hstr = a[1].strip
	    when /^rth\-alt/
	      @rthh = a[1].strip.to_i
	    when /^margin/
	      @margin = a[1].strip.to_i
	    when /^sanity/
	      @sanity = a[1].strip.to_i
	    end
	  end
	end
      end
    end
  end

  def initialize
    @pf=@hstr=nil
    @margin=nil
    @rthh = nil
    @save = nil
    @noplot = false
    @noalts = false

    @sanity = SANITY

    read_config

    @hstr=(@hstr||ENV['MWP_HOME'])

    begin
      opts = OptionParser.new
      opts.banner = %Q!Usage: mwp-plot-elevations.rb [options] mission_file

mwp-plot-evelations.rb plots a  iNav\/ MW XML mission file (as generated by "mwp",
"ezgui", "mission planner for iNav") against terrain elevation data.

In order to do this, you must have an internet connection, as the elevation data is
obtained from the Bing Maps elevation service. You should provide a home
location (so home -> WP1 and RTH can then be modelled).

Graphical output is a SVG file and requires "gnuplot" be installed. The output
can also be output as a CSV file. If neither a plot file nor an output file
is provided, CSV is written to standard output.

The environment variable MWP_HOME if defined, is also consulted for a
home location (the -h option takes preference). Setting may also be
read from $HOME\/.config\/mwp\/elev-plot, .\/.elev-plot.rc or $HOME\/.elev-plot.rc.

!
      opts.separator ""
      opts.separator "Options:"
      opts.on("-p",'--plotfile=FILE', 'Plot file (SVG)') {|o| @pf = o }
      opts.on("-h",'--home=LOCATION', 'Home location as "lat long"') {|o| @hstr = o }
      opts.on("-o",'--output=FILE', 'Revised mission') {|o| @save = o }
      opts.on("-r",'--rth-alt=ALT', 'RTH altitude', Integer) {|o| @rthh = o }
      opts.on("-m",'--margin=M', 'Clearance Margin (m)', Integer) {|o| @margin = o }
      opts.on("-P",'--no-plotting', "Don't plot anything, at all") {|o| @noplot = true}
      opts.on("-A",'--no-mission-alts', "Don't use extant mission altitudes") {|o| @noalts = true }
      rest = opts.parse(ARGV)
      @file = rest[0]
    rescue
      STDERR.puts "Unrecognised option\n\n"
      STDERR.puts opts.help
      exit
    end
    abort "Need a mission file" unless @file
    abort "You must provide an estimed home position" unless @hstr
    @tmps=[]
    at_exit {File.unlink(*@tmps) unless @tmps.empty?}
  end

  def mktemp sfx=nil
    tf = File.join Dir.tmpdir,".mi-#{$$}-#{rand(0x100000000).to_s(36)}-"
    tf << sfx if sfx
    @tmps << tf
    tf
  end

  def mkplt ap, mx, lwp, rth,fixups
    dists=[]
    wps=[]
    gl=[]
    ml=[]
    cl=[]
    fx=[]
    mfile = fxfile = nil
    nf = 0
    ap.each_with_index do |p,n|
      case p[:typ]
      when 'h','r',1..60
	dists << p[:dist]
	wps << "\"#{p[:label]}\" #{p[:dist]}"
	ml << [p[:dist], p[:pabsalt]]
	unless fixups.empty?
	  fxalt = fixups[nf].nil?  ?  p[:absalt] : p[:absalt] + fixups[nf]
	  fx << [p[:dist], fxalt]
	  nf += 1
	end
	if rth
	  if n == lwp
	    if p[:absalt] < ap[rth][:absalt]
	      ml << [p[:dist], ap[rth][:absalt]]
	      unless fixups.empty?
		fxalt = fixups[-1].nil?  ?  p[:absalt] : p[:absalt] + fixups[-1]
		if fxalt < ap[rth][:absalt]
		  fx << [p[:dist], ap[rth][:absalt]]
		end
	      end
	    end
	  end
	end
      end
      if @margin
	  cl << [p[:dist], @margin+p[:amsl]]
      end
      gl << [p[:dist], p[:amsl]]
    end

    infile0 = mktemp ".csv"
    File.open(infile0, 'w') do |fh|
      fh.puts %w/Dist MElev/.join("\t")
      ml.each do |p|
	fh.puts p.join("\t")
      end
    end

    infile1 = mktemp ".csv"
    File.open(infile1, 'w') do |fh|
      fh.puts %w/Dist AMSL/.join("\t")
      gl.each do |p|
	fh.puts p.join("\t")
      end
    end

    unless fx.empty?
      fxfile = mktemp ".csv"
      File.open(fxfile, 'w') do |fh|
	fh.puts %w/Dist AMSL/.join("\t")
	fx.each do |p|
	  fh.puts p.join("\t")
	end
      end
    end

    if @margin
      mfile = mktemp ".csv"
      File.open(mfile, 'w') do |fh|
	fh.puts %w/Dist Clear/.join("\t")
	cl.each do |p|
	  fh.puts p.join("\t")
	end
      end
    end

    str = "#!/usr/bin/gnuplot -p\n"
    str << %Q/
set bmargin 8
set key top right
set key box
set grid
set xtics (#{dists.join(',')})
set xtics rotate by 45 offset -0.8,-1.5
set x2tics rotate by 45
set x2tics (#{wps.join(',')})
set xlabel "Distance"
set bmargin 3
set offsets graph 0,0,0.01,0

set title "Mission Elevation"
set ylabel "Elevation"
show label
set xrange [ 0 : ]
set datafile separator "\t"
set yrange [ #{mx} : ]

set terminal push
set terminal svg enhanced background rgb 'white' font "sans,9" rounded
set output \"#{@pf}\"

plot \"#{infile1}\" using 1:2 t "Terrain" w filledcurve y1=#{mx} lt -1 lw 2  lc rgb "green", \"#{infile0}\" using 1:2 t "Mission" w lines lt -1 lw 2  lc rgb "red" /
    if mfile
      str << ", \"#{mfile}\" using 1:2 t \"Margin\" w lines lt -1 lw 2  lc rgb \"blue\""
    end
    if fxfile
      str << ", \"#{fxfile}\" using 1:2 t \"Updated\" w lines lt -1 lw 2  lc rgb \"orange\""
    end
    str << "
set terminal pop
set output
replot
"

    plt = mktemp ".plt"
    File.open(plt, 'w') {|fh| fh.puts str}
    gerr = mktemp ".log"
    unless system("gnuplot -p #{plt}  2>#{gerr}") == true
      s = IO.read(gerr)
      abort "Failed to run gnuplot: #{s}"
    end
  end

  def rewrite fixups
    doc = Nokogiri::XML(open(@file))
    now = Time.now.strftime("%FT%T%z")
    x = doc.at("/MISSION/mwp|/mission/mwp")
    if  x.nil?
      doc.at('MISSION').add_child("<mwp generator=\"plot-elevations.rb (mwptools)\" save-date=\"#{now}\"")
    else
      x['generator'] = 'plot-elevations.rb (mwptools)'
      x['save-date'] = now
    end

    fixups.each_with_index do |f,n|
      unless f.nil?
	q = "//MISSIONITEM[@no='#{n}']|//missionitem[@no='#{n}']"
	x = doc.xpath(q).first
	unless  x.nil?
	  x['alt'] = f.to_s
	end
      end
    end
    File.open(@save,'w') {|fh| fh.puts doc.to_s}
  end

  def read
    ipos = []
    lx=ly=nil
    tdist = 0
    hlat = nil
    hlon = nil
    hp = @hstr.split(' ')
    if hp.size != 2
      hp = @hstr.split(',')
    end

    # Too ugly, one should not have to do this in the 21st centuary
    hp0 = hp[0].gsub(',','.')
    hp1 = hp[1].gsub(',','.')
    hlat = hp0.to_f
    hlon = hp1.to_f

    #STDERR.puts ("hstr [#{@hstr}] lat lon #{hlat} #{hlon}")

    ipos << { :no => 0, :lat => hlat, :lon => hlon, :alt => 0, :oa => 0,
      :act=> 'HOME', :p1 => '0', :p2 => '0', :p3 => '0',
      :cse => nil, :dist => 0.0, :tdist => 0.0}
    ly = hlat
    lx = hlon

    doc = Nokogiri::XML(open(@file))
    doc.xpath('//MISSIONITEM|//missionitem').each do |t|
      action=t['action']
      next if action == 'SET_POI' || action == 'SET_HEAD' || action == 'JUMP'
      p3 = t['parameter3']
      unless p3.nil?
        if p3.to_i != 0
          abort "Relative altitudes only"
        end
      end
      no = t['no'].to_i
      lat = t['lat'].to_f
      lon = t['lon'].to_f
      oa = t['alt'].to_i
      alt = @noalts ? 0 : oa
      if action == 'RTH'
	if @hstr.nil?
	  break
	else
	  lat = hlat
	  lon = hlon
	  alt = 0
	end
      end
      c = nil
      d = 0
      if lx and ly
	c,d = Geocalc.csedist ly,lx,lat,lon
	d = d*1852
	if no == 1 and d > @sanity
	  abort "1st WP is #{d.to_i}m from home, sanity is #{@sanity}m"
	end
      end
      lx = lon
      ly = lat
      tdist += d
      ipos << {:no => no, :lat => lat, :lon => lon, :alt => alt, :act => action,
	:p1 => t['parameter1'], :p2 => t['parameter2'], :p3 => t['parameter3'],
	:cse => c, :dist => d, :tdist => tdist, :oa => oa}
      break if action == 'POSHOLD_UNLIM' || action == 'LAND'
    end
    ipos
  end

  def pca pts
    lat = 0
    lon = 0
    str=''
    (0...pts.length).step(2).each do |i|
      nlat = (pts[i] * 100000).round.to_i
      nlon = (pts[i+1] * 100000).round.to_i
      dy = nlat - lat
      dx = nlon - lon
      lat = nlat
      lon = nlon

      dy = (dy << 1) ^ (dy >> 31)
      dx = (dx << 1) ^ (dx >> 31)
      index = ((dy + dx) * (dy + dx + 1) / 2) + dy
      while (index > 0)
	rem = index & 31
	index = (index - rem) / 32
	if (index > 0)
	  rem += 32
	end
	str << "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"[rem]
      end
    end
    str
  end

  def get_bing_elevations pts, nsam=0
    act = (nsam <= 0) ? 'List' : 'Polyline'
    u="http://dev.virtualearth.net/REST/v1/Elevation/#{act}"
    u << "?key="
    u << Base64.decode64(BKEY)
    if nsam > 0
      u << "&samp=#{nsam}"
    end
    uri = URI.parse(u)
    rstr = "points="
    rstr << pca(pts)

    alts=nil
    http = Net::HTTP.new(uri.host, uri.port)
    headers = {"Content-Length" => rstr.length.to_s,
      "Content-Type" => "text/plain; charset=utf-8"}

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = rstr
    response = http.request(request)
    if response.code == '200'
      jalts=JSON.parse(response.body)
      alts = jalts['resourceSets'][0]['resources'][0]['elevations']
    end
    alts
  end

  def to_info pos
    pa=[]
    pos.each {|p| pa << p[:lat] << p[:lon]}
    alts = get_bing_elevations pa
    if alts.size != (pa.size/2)
      abort "warning: bing mismatch, requested #{pa.size/2}, got #{alts.size}\nThis is probably due to duplicate points in your mission\nPlease raise a bug if you don't think your mission is to blame"
    end
    mx = 99999
    allpts = []
    pos.each_with_index do |p,j|
      agl = alts ? alts[0] + p[:alt]  : nil
      pagl = alts ? alts[0] + p[:oa]  : nil
      terralt = alts ? alts[j] : nil
      terralt ||= alts[0]
      mx = terralt if terralt < mx
      lbl = nil
      typ = nil
      case p[:act]
      when 'HOME'
	lbl = 'Home'
	typ = 'h'
      when 'RTH'
	lbl = 'RTH'
	typ = 'r'
      else
	lbl = "WP%d" % p[:no]
	typ = p[:no]
      end
      allpts << { :dist => p[:tdist].to_i, :typ => typ,
	:absalt => agl, # wgs84 alt of WP
	:amsl => terralt, # wgs84 alt of ground here
	:melev => p[:alt], # mission 'alt'
	:label => lbl,
	:pabsalt => pagl
      }
    end

      # needs to calc number
    np = (pos[-1][:tdist]/30).to_i
    np=1023 if np > 1023
    elevs = get_bing_elevations pa, np+1
    dx=pos[-1][:tdist]/np.to_f
    0.upto(np) do |j|
      allpts << { :dist => (dx*j).to_i, :amsl => elevs[j], :typ => "g" }
    end
    unless @pf.nil?
      @pf << ".svg" unless @pf.match(/\.svg$/)
    end
    allpts.sort! {|a,b| a[:dist] <=> b[:dist]}

    mx = (mx / 10) * 10
    np = allpts.size - 1
    tdel=[]
    1.upto(np) do |j|
      if allpts[j-1][:dist] == allpts[j][:dist]
	if allpts[j][:typ] == 'g'
	  tdel << j
	elsif allpts[j-1][:typ] == 'g'
	  tdel << j-1
	end
      end
    end
    tdel.reverse.each {|j| allpts.delete_at(j) }

    h0 = allpts[0][:amsl]
    ma =nil
    rth = nil
    lwp = nil
    l0 = nil

    allpts.each_with_index do |p,n|
      case p[:typ]
      when 'r'
	rth = n
	rh = @rthh ? @rthh : allpts[lwp][:melev]
	allpts[n][:melev] = rh
	allpts[n][:absalt] = rh + h0
	allpts[n][:pabsalt] = rh + h0
      when 1..60
	lwp = n
      end
    end

    fixups=[]

    if @save
      allpts.each_with_index do |p,n|
	case p[:typ]
	when 'h'
	  l0 = p[:typ]
	  ma = h0
	when 'g'
	  ma = p[:amsl] if p[:amsl] > ma
	when 'r',1..60
	  if n != allpts.size - 1
	    ma = allpts[n+1][:amsl] if allpts[n+1][:amsl] > ma
	  else
	    ma = p[:amsl] if p[:amsl] > ma
	  end
	  cl = p[:absalt] - ma
	  if @margin
	    if cl < @margin
	      [l0,p[:typ]].each do |k|
		next if k == 'h' || k == 'r'
		dif = @margin - cl
		if fixups[k].nil?
		  fixups[k] = dif
		else
		  if dif > fixups[k]
		    fixups[k] = dif
		  end
		end
	      end
	    end
	  end
	  l0 = p[:typ]
	  ma = p[:amsl]
	end
      end
    end

    if @pf.nil?
      @pf = mktemp ".svg"
    end

    unless @noplot
      mkplt allpts, mx, lwp, rth, fixups
    end

    unless fixups.empty?
      fixups.each_with_index do |f,n|
	unless f.nil?
	  fixups[n] += pos[n][:alt]
	end
      end
      if @save
	rewrite fixups
      end
    end
  end
end

g = MReader.new
pos = g.read
if pos and pos.size > 1
  g.to_info pos
else
  STDERR.puts "Truncated mission"
  exit 1
end
