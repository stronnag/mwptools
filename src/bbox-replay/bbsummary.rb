#!/usr/bin/env ruby

# Copyright (c) 2019 Jonathan Hudson <jh+mwptools@daria.co.uk>

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'csv'
require 'optparse'
require 'open3'
begin
  require 'json'
  have_js = true
rescue LoadError
  have_js = false
end

include Math
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

NORMDELAY=0.1
REASONS = %w/NONE TIMEOUT STICKS SWITCH_3D SWITCH KILLSWITCH FAILSAFE NAVIGATION/

$vbatscale=1.0
$base_alt = nil

def get_gps r,baro=true
  nsf = 0
  ns = r[:gps_numsat].to_i
  if r.has_key? :gps_fixtype
    nsf = r[:gps_fixtype].to_i + 1
  else
    nsf = case ns
	  when 0
	    0
	  when 1,2,3,4
	    1
	  when 5,6
	    2
	  else
	    3
	  end
  end
  alt = 0
  if baro
    alt = r[:baroalt_cm].to_i
  else
    gps_alt = r[:gps_altitude].to_i
    if $base_alt == nil
      $base_alt = gps_alt
    end
    alt = (gps_alt - $base_alt)*100
  end

  {lat: r[:gps_coord0].to_f,
    lng: r[:gps_coord1].to_f,
    spd: r[:gps_speed_ms].to_i,
    alt: alt,
    fix: nsf}
end

def get_origin r
  {lat: r[:gps_coord0].to_f,
    lng: r[:gps_coord1].to_f}
end

def get_amps r
  amps = nil
  if r.has_key? :amperagelatest_a
    amps = r[:amperagelatest_a].to_f
  elsif r.has_key? :amperage_a
    amps = r[:amperage_a].to_f
  elsif r.has_key? :currentvirtual_a
    amps = r[:currentvirtual_a].to_f
  end
  amps
end

def format_time t
  if t
    t = t / 1000000
    m = t / 60
    s = t % 60
    "@%d:%02d" % [m,s]
  else
    ""
  end
end

if RUBY_VERSION.match(/^1/)
  abort "This script requires a miniumum of Ruby 2.0"
end

idx = nil
gpshd = 0
dumph = false
decoder="blackbox_decode"

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] file\nSummarise bbox logs"
  opt.on('-i','--index=IDX',Integer){|o|idx=o}
  opt.on('-d','--dump-headers'){dumph=true}
  opt.on('-v','--verbose'){$verbose=true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

intvl = 100000

RDISARMS = %w/NONE TIMEOUT STICKS SWITCH_3D SWITCH KILLSWITCH FAILSAFE NAVIGATION/

begin
  Open3.capture3("#{decoder} --help")
rescue
  abort "Can't run 'blackbox_decode' is it installed and on the PATH?"
end

bbox = (ARGV[0]|| abort('no BBOX log'))

gitinfos=[]
disarms=[]
vname = nil

File.open(bbox,'rb') do |f|
  f.each do |l|
    if m = l.match(/^H Firmware revision:(.*)$/)
      gitinfos << m[1]
      ivers = m[1]
      if iv=ivers.match(/INAV (\d+).(\d+).(\d+)/)
	if iv[1].to_i <  2
	  need_vbat_scale = true
	elsif iv[1].to_i == 2 and iv[2] == '0' and iv[2] == '0'
	  vbstate = true
	else
	  need_vbat_scale = false
	end
      end
    elsif m = l.match(/^H Firmware date:(...) (\d{2}) (\d{4})/)
      if vbstate == true
	if m[3] == '2018'
	  if m[1] == 'Apr' || m[1] == 'May' || m[1] == 'Jun' ||
	      (m[1] == 'Jul' and m[2].to_i < 7)
	    need_vbat_scale = true
	  else
	    need_vbat_scale = false
	  end
	end
      end
    elsif m = l.match(/^H mag_hardware:(\d+)$/)
      have_mag = m[1] != '0'
    elsif m = l.match(/^H vbat_scale:(\d+)$/)
      if need_vbat_scale
	$vbatscale = m[1].to_f / 110.0
      end
    elsif m = l.match(/^H Craft name:(.*)$/)
      vname = m[1] unless m[1].empty?
    elsif m = l.match(/End of log \(disarm reason:(\d+)/)
      disarms << m[1].to_i
    end
  end
end

#puts "Log entries #{gitinfos.size}"
#puts "Disarm entries #{disarms.size}"

idx ||= gitinfos.size

nul="/dev/null"
if Gem.win_platform?
  nul = "NUL"
  csv_opts[:row_sep] = "\r\n" if RUBY_PLATFORM.include?('cygwin')
end

csv_opts = {
  col_sep: ",",
  headers: :true,
  header_converters: ->(f){f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
  return_headers: true}

extra_args = {}
if vname && have_js
  pref_fn = File.join(ENV["HOME"],".config", "mwp", "replay_ltm.json")
  if File.exist? pref_fn
    json = IO.read(pref_fn)
    prefs = JSON.parse(json, {:symbolize_names => true})
    decl = prefs[:declination].to_f
    autotyp = prefs[:auto]
    nobaro = prefs[:nobaro]
    extra_args = prefs[:extra]
  end
end

xcmd = decoder
xcmd << " --merge-gps"
unless decl.nil?
  xcmd << " --declination-dec #{decl}"
end
if vname
  exargs=''
  extra_args.each do |k,v|
    if vname.match(/#{k.to_s}/)
      exargs << ' ' << v
    end
  end
  xcmd << exargs
end

xcmd << " --stdout"
xcmd << " 2>#{nul}"

1.upto(idx) do |ilog|

  cmd = xcmd.dup
  cmd = cmd << " --index #{ilog}" << " \"#{bbox}\""

  llat = nil
  llng = nil
  us=nil
  st=nil
  origin = nil
  nv = 0
  icnt = 0

  lindex = 0
  sts = {
    :dist => 0,
    :rmax => {v: 0, t: nil},
    :amax => {v: -99999, t: nil},
    :cmax => {v: 0, t: nil},
    :dura => 0,
    :smax => {v: 0, t: nil},
  }

  IO.popen(cmd,'rt') do |pipe|
    csv = CSV.new(pipe, csv_opts)
    csv.each do |row|
      if lindex == 0
	hdrs = row
	if dumph
	  require 'ap'
	  ap hdrs
	  exit
	end
	abort 'Not a useful INAV log' if hdrs[:gps_coord0].nil?
      else
	next if row[:gps_numsat].to_i == 0
	us = row[:time_us].to_i
	st = us if st.nil?
	if us > nv
	  nv = us + intvl
	  # Check for armed and GPS (for origin)
	  if origin.nil? and row[:gps_numsat].to_i > 5
	    o = get_origin row
	    if o[:lat] != 0 and o[:lng] != 0
	      origin = o
	      llat = origin[:lat]
	      llng = origin[:lng]
	    end
	  end
	  next unless origin

	  amps = get_amps row
	  if amps and amps > sts[:cmax][:v]
	    sts[:cmax][:v] = amps
	    sts[:cmax][:t] = us - st
	  end

	  g = get_gps row
	  if llat and llng
	    c,d = Poscalc.csedist(llat,llng,g[:lat],g[:lng])
            sts[:dist] += d
	  end

	  llat = g[:lat]
	  llng = g[:lng]

	  c,d = Poscalc.csedist(origin[:lat],origin[:lng],g[:lat],g[:lng])
	  if d > sts[:rmax][:v]
	    sts[:rmax][:v] = d
	    sts[:rmax][:t] = us - st
	  end
	  if g[:alt] >  sts[:amax][:v]
	    sts[:amax][:v] = g[:alt]
	    sts[:amax][:t] = us - st
	  end
	  if g[:spd] >  sts[:smax][:v]
	    sts[:smax][:v] = g[:spd]
	    sts[:smax][:t] = us - st
	  end
	end
      end
      lindex += 1
    end
  end
  sts[:dura] = ((us - st)/1000000).to_i
  puts "#{bbox} / #{ilog}\n"
  puts "Firmware : #{gitinfos[ilog-1]}"
  puts "Distance : #{(1852*sts[:dist]).to_i}m"
  puts "Range    : #{(1852*sts[:rmax][:v]).to_i}m #{format_time(sts[:rmax][:t])}"
  puts "Altitude : #{(sts[:amax][:v]/100).to_i}m #{format_time(sts[:amax][:t])}"
  puts "Speed    : #{sts[:smax][:v]}m/s #{format_time(sts[:smax][:t])}"
  puts "Current  : #{sts[:cmax][:v]}A #{format_time(sts[:cmax][:t])}"
  puts "Duration : #{sts[:dura]}"
  if disarms[ilog-1]
    puts "Disarmed : #{REASONS[disarms[ilog-1]]}"
  end
end
