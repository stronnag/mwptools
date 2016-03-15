#!/usr/bin/ruby

# Extract heading & gps_course for analysis
# MIT licence
include Math
require 'csv'
require 'optparse'

module Poscalc
  RAD = 0.017453292

  def Poscalc.d2r d
    private
    d*RAD
  end

def Poscalc.r2d r
    private
    r/RAD
  end

  def Poscalc.nm2r nm
    private
    (PI/(180*60))*nm
  end

  def Poscalc.r2nm r
    private
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

idx = 1
decl = -1.3
llat = 0
llon = 0
minthrottle = 1500

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX'){|o|idx=o}
  opt.on('-d','--declination=DEC',Float,'Mag Declination (default -1.3)'){|o|decl=o}
  opt.on('-t','--min-throttle',Integer,'Min Throttle for comparison (1500)'){|o|minthrottle=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end
bbox = (ARGV[0]|| abort('no BBOX log'))
cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --merge-gps"
cmd << " --declination #{decl}"
cmd << " --simulate-imu"
cmd << " --stdout"
cmd << " " << bbox
IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)
  hdrs = csv.shift
  cse = nil
  puts %w/time(s) throttle navstate gps_speed_ms gps_course heading attitude2 calc/.join(",")
  csv.each do |c|
    lat = c[:gps_coord0].to_f
    lon = c[:gps_coord1].to_f
    if c[:navstate].to_i == 1 and
	c[:rccommand3].to_i > minthrottle and
	c[:gps_speed_ms].to_f > 2.0
      mag0 = c[:heading]
      mag1 = c[:attitude2].to_f/10.0
      if  llon != 0 and llat != 0
	if llat != lat && llon != lon
	  cse,distnm = Poscalc.csedist(llat,llon, lat, lon)
	  cse = (cse * 10.0).to_i / 10.0
	end
      else
	cse = nil
      end
      ts = c[:time_us].to_f / 1000000
      puts [ts, c[:rccommand3].to_i, c[:navstate].to_i, c[:gps_speed_ms].to_f,
	c[:gps_ground_course].to_i, mag0,mag1,cse].join(",")
    end
    llat = lat
    llon = lon
  end
end
