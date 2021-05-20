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

idx = 1
every = 0

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX',Integer){|o|idx=o}
  opt.on('-n','--modulo=N',Integer){|o|every=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

llat = 0
llon = 0
cse = nil
gitinfo = nil

bbox = (ARGV[0]|| abort('no BBOX log'))

File.open(bbox,'rb') do |f|
  f.each do |l|
    if m = l.match(/^H Firmware revision:(.*)$/)
      gitinfo = m[1]
      break
    end
  end
end

iv=nil
if gitinfo.nil?
  abort "Doesn't look like Blackbox (#{bbox})"
else
  if m=gitinfo.match(/^INAV (\d{1})\.(\d{1})\.(\d{1}) \((\S*)\) (\S+)/)
    iv = [m[1],m[2],m[3]].join('.')
  end
end

inavers = nil
if iv.nil?
  iv = "2.0.99" # best guess
end

inavers =  get_state_version iv

cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --merge-gps"
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
  st = nil
  puts %w/time(s) throttle navstate gps_speed_ms gps_course attitude2 calc delta/.join(",")
  n = 0
  csv.each do |c|
    n += 1
    if every != 0
      next unless n % every == 0
    end
    ts = c[:time_us].to_f / 1000000
    st = ts if st.nil?
    ts -= st
    lat = c[:gps_coord0].to_f
    lon = c[:gps_coord1].to_f
    if  llon != 0 and llat != 0
      if llat != lat && llon != lon
        cse,distnm = Poscalc.csedist(llat,llon, lat, lon)
        cse = cse.to_i
      end
    else
      cse = nil
    end
    mag0 = (c[:attitude2].to_f/10.0).to_i
    asx = INAV_STATES[inavers][c[:navstate].to_i].to_s
    if asx.start_with?("nav_state_")
      asx = asx[10..-1]
    end
    ftm = "%.3f" % ts
    puts [ftm, c[:rccommand3].to_i, asx, c[:gps_speed_ms].to_f,
	  c[:gps_ground_course].to_i, mag0,cse, (mag0-c[:gps_ground_course].to_i).abs].join(",")
    llat = lat
    llon = lon
  end
end
