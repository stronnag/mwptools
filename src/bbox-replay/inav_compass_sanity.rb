#!/usr/bin/ruby

# Naive compass sanity checker
# MIT licence

require 'csv'
require 'optparse'
require_relative 'inav_states'

def get_heading_diff a, b
  diff = b - a;
  absdiff = diff.abs
  if absdiff <= 180
    return absdiff == 180 ? absdiff : diff
  elsif (b > a)
    return absdiff - 360
  else
    return 360 - absdiff
  end
end

angle = 45
period = 3

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [files ...]"
  opt.on('-a','--angle=DEGS',Float,'Allowed deviation, default 45°'){|o| angle = o}
  opt.on('-p','--period=SECS',Integer,'Period, default 3s'){|o| period = o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

ARGV.each do |bbox|

  idx = 1
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
  if m=gitinfo.match(/^INAV (\d{1})\.(\d{1})\.(\d{1}) \(([0-9A-Fa-f]{7,})\) (\S+)/
		     )
    iv = [m[1],m[2],m[3]].join('.')
  end
  inavers =  get_state_version iv

  arry = []
  [:nav_state_idle,
    :nav_state_althold_in_progress,
    :nav_state_poshold_3d_in_progress,
    :nav_state_rth_head_home,
    :nav_state_waypoint_in_progress,
    :nav_state_cruise_2d_in_progress,
    :nav_state_cruise_3d_in_progress].each do |s|
    arry << INAV_STATES[inavers].key(s)
  end

  vbox = true
  while vbox do
    cmd = "blackbox_decode"
    cmd << " --index #{idx}"
    cmd << " --stdout"
    cmd << " --merge-gps"
    cmd << " --unit-frame-time s"
    cmd << " 2>/dev/null " << bbox

    IO.popen(cmd,'r') do |p|
      csv = CSV.new(p, :col_sep => ",",
		    :headers => :true,
		    :header_converters =>
		    ->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		    :return_headers => true)
      hdrs = csv.shift
      anom = []
      if hdrs == nil
	vbox = false
	break
      end
      st = nil
      magdt = -1
      xgcse = xmhead = nil
      csv.each do |c|
	ts = c[:time_s].to_f
	st = ts if st.nil?
	rt = ts - st
	if arry.include? c[:navstate].to_i
	  if c[:gps_speed_ms].to_f  > 3
	    gcse = c[:gps_ground_course].to_i
	    mhead = c[:attitude2].to_i/10
	    if get_heading_diff(gcse, mhead).abs > angle
	      if magdt == -1
		xgcse = gcse
		xmhead = mhead
		magdt = rt
#		puts "Set mag #{gcse} #{mhead} #{rt.to_i}"
	      end
	    elsif magdt != -1
#	      puts "clear mag #{gcse} #{mhead} #{rt.to_i}"
	      magdt = -1
	    end
	  else
	    magdt = -1
	  end
	end
	if magdt != -1 and (rt - magdt) > period
	  anom << "Mag Anomlay at %.3f (%d %d)\n" % [magdt, xgcse, xmhead]
	  magdt = -1
	end
      end

      if anom.length > 0
	puts bbox
	anom.each {|a| puts a}
	puts
      end

      if vbox == false
	break
      else
	idx += 1
      end
    end
  end
end
