#!/usr/bin/ruby

# Extract hw status for analysis
# MIT licence

require 'csv'
require 'optparse'
require_relative 'inav_states'

idx = 1
hw=-1
SENSORS=[:gyro, :acc, :mag, :baro, :gps, :rangef, :pitot]
STATES=['none','OK','unavailable','unhealthy']

def mkmask
  m = 0
  0.upto(6) do |n|
    m |= 2 << (2 * n)
  end
  m
end

def hwstatus val
  ret = 0
  vals={}
  0.upto(6) do |n|
    sv = val & 3
    ret = -1 if sv > 1 or (n < 2 and sv != 1)
    vals[SENSORS[n]] = sv
    val = (val >> 2)
  end
  [ret,vals]
end

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX',Integer){|o|idx=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

bbox = (ARGV[0]|| abort('no BBOX log'))

gitinfos=[]
File.open(bbox,'rb') do |f|
  f.each do |l|
    if m = l.match(/^H Firmware revision:(.*)$/)
      gitinfos << m[1]
    end
  end
end

gitinfo = gitinfos[idx - 1]

iv=nil
if m=gitinfo.match(/^INAV (\d{1})\.(\d{1})\.(\d{1}) \(([0-9A-Fa-f]{7,})\) (\S+)/)
  iv = [m[1],m[2],m[3]].join('.')
end

inavers=(STATE_EQ[iv] || iv || "1.3.0")
STDERR.puts "iNav version = #{iv} (states eq #{inavers})"

cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --stdout"
cmd << " " << bbox

IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)
  hdrs = csv.shift
  st = nil
  nstate = -1

  csv.each do |c|
    ts = c[:time_us].to_f / 1000000
    st = ts if st.nil?
    if c[:hwhealthstatus].to_i != hw
      hw = c[:hwhealthstatus].to_i
      xts  = ts - st
      ret,vals = hwstatus hw

      print "%.3fs HW Status change (%x %d)" % [xts,hw,hw]
      puts " status: #{(ret==0) ? 'OK' : 'Failure'}"
      vals.each do |k,v|
	puts [k.to_s,STATES[v]].join("\t")
      end
      puts
    end
  end
end
