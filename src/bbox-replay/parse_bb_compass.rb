#!/usr/bin/ruby

# Extract heading & gps_course for analysis
# MIT licence
include Math
require 'csv'
require 'optparse'
require_relative 'inav_states_data'

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
end


def list_states
  STATES.each_with_index do |s,n|
    puts "%2d : %s\n" % [n,s]
  end
  exit
end

idx = 1
decl = -1.3
llat = 0
llon = 0
minthrottle = 1500
states = [1]
allstates = false
sane = false
missing = false
plotfile=nil
outf = nil
rm = false
thr = false

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('--all-states') {|o| allstates = true}
  opt.on('--sane') {|o| sane = true}
  opt.on('--list-states') { list_states }
  opt.on('--missing') { missing=true }
  opt.on('--plot') { |o| plotfile=o}
  opt.on('--thr') { thr=true}
  opt.on('-o','--output=FILE'){|o|outf=o}
  opt.on('-i','--index=IDX'){|o|idx=o}
  opt.on('-d','--declination=DEC',Float,'Mag Declination (default -1.3)'){|o|decl=o}
  opt.on('-t','--min-throttle=THROTTLE',Integer,'Min Throttle for comparison (1500)'){|o|minthrottle=o}
  opt.on('-s','--states=a,b,c', Array, 'Nav states to assess [1]'){|o|states=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

if sane
  states=[1,16,24]
elsif allstates
  states=*(0..38)
else
  states.map! {|s| s.to_i}
end

bbox = (ARGV[0]|| abort('no BBOX log'))
cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --merge-gps"
cmd << " --declination #{decl}"
cmd << " --stdout"
cmd << " " << bbox

if outf.nil? && plotfile.nil?
  outf =  STDOUT.fileno
elsif outf.nil?
  outf = "#{ARGV[0]}.csv"
  rm = true
end

IO.popen(cmd,'r') do |p|
  File.open(outf,"w") do |fh|
    csv = CSV.new(p, :col_sep => ",",
		  :headers => :true,
		  :header_converters =>
		  ->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		  :return_headers => true)
    hdrs = csv.shift
    cse = nil
    st = nil
    lt = 0
    ostr = %w/time(s) navstate gps_speed_ms gps_course attitude2 calc/.join(",")
    if thr
      ostr << ",throttle"
    end
    fh.puts ostr
    csv.each do |c|
      ts = c[:time_us].to_f / 1000000
      st = ts if st.nil?
      ts -= st
      if ts - lt > 0.1
        lat = c[:gps_coord0].to_f
        lon = c[:gps_coord1].to_f
        if states.include? c[:navstate].to_i and
	  c[:rccommand3].to_i > minthrottle and
	  c[:gps_speed_ms].to_f > 2.0
          mag1 = c[:attitude2].to_f/10.0
          if  llon != 0 and llat != 0
	    if llat != lat && llon != lon
	      cse,distnm = Poscalc.csedist(llat,llon, lat, lon)
	      cse = (cse * 10.0).to_i / 10.0
	    end
          else
	    cse = nil
          end
          ostr = [ts, c[:navstate].to_i, c[:gps_speed_ms].to_f, c[:gps_ground_course].to_i, mag1,cse].join(",")
          if thr
            ostr << ",#{c[:rccommand3].to_i}"
          end
          fh.puts ostr
        elsif missing
          fh.puts [ts,-1,-1,-1,-1,-1,-1].join(',')
        end
        llat = lat
        llon = lon
        lt = ts
      end
    end
  end
end
if plotfile
  pltfile = DATA.read
  if thr
    pltfile.chomp!
    pltfile << ', filename using 1:7 t "Throttle" w lines lt -1 lw 3  lc rgb "#807fd0e0"'
  end
  File.open(".inav_gps_dirn.plt","w") {|plt| plt.puts pltfile}
  system "gnuplot -e 'filename=\"#{outf}\"' .inav_gps_dirn.plt"
  STDERR.puts "Graph in #{outf}.svg"
  File.unlink ".inav_gps_dirn.plt"
end
File.unlink outf if rm

__END__
set bmargin 8
set key top right
set key box
set grid
set termopt enhanced
set termopt font "sans,8"
set xlabel "Time(s)"
set title "Direction Analysis"
set ylabel ""
show label
set xrange [ 0 : ]
#set yrange [ 0 : ]
set datafile separator ","
set terminal svg background rgb 'white' font "Droid Sans,9" rounded
set output filename.'.svg'
plot filename using 1:3 t "GPS Speed" w lines lt -1 lw 2  lc rgb "red", filename using 1:4 t "GPS Course" w lines lt -1 lw 2  lc rgb "gold" , filename using 1:5 t "Attitude[2]" w lines lt -1 lw 2  lc rgb "green", filename using 1:6 t "Calc" w lines lt -1 lw 2  lc rgb "brown"
