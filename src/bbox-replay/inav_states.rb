#!/usr/bin/ruby

# Analyse iNav mode changes
# MIT licence

require 'csv'
require 'optparse'
require_relative 'inav_states_data'

RDISARMS = %w/NONE TIMEOUT STICKS SWITCH_3D SWITCH KILLSWITCH FAILSAFE NAVIGATION/

idx = 1
verbose = nil
pstate = -1
force = nil

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX',Integer){|o|idx=o}
  opt.on('-v','--verbose') {verbose=true}
  opt.on('-f','--force') {force=true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

bbox = (ARGV[0]|| abort('no BBOX log'))

gitinfos=[]
disarms=[]

File.open(bbox,'rb') do |f|
  f.each do |l|
    if m = l.match(/^H Firmware revision:(.*)$/)
      gitinfos << m[1]
    elsif m = l.match(/End of log \(disarm reason:(\d+)/)
      disarms << m[1].to_i
    end
  end
end

gitinfo = gitinfos[idx - 1]

if gitinfo.nil?
  if force
  else
    abort "Doesn't look like Blackbox (#{bbox})"
  end
end

iv=nil
if gitinfo and  m=gitinfo.match(/^INAV (\d{1})\.(\d{1})\.(\d{1}) \((\S*)\) (\S+)/)
  iv = [m[1],m[2],m[3]].join('.')
end

inavers = nil
if iv.nil?
  if force
    iv = "2.0.99"
  else
    iv ="0"
  end
end
inavers =  get_state_version iv

STDERR.puts "iNav version = #{iv} (states eq #{inavers})" if verbose

puts "#{File.basename(bbox)}: #{gitinfos[idx-1] if gitinfos.size >= idx}"

nul = !Gem.win_platform? ? '/dev/null' : 'NUL'

cmd = ''
cmd << (ENV["BLACKBOX_DECODE"] || "blackbox_decode")
cmd << " --index #{idx}"
cmd << " --stdout"
cmd << " 2>#{nul}"
cmd << " " << bbox

IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)

  nhdr=false
  itn=0
  nstate = -1
  istate = 'IDLE'
  st = nil
  xts=0
  ts=0
  nflags = 0

  csv.each do |c|
    if  nhdr == false
      hdrs = c
      nhdr = true
    else
      ts = c[:time_us].to_f / 1000000
      itn = c[:loopiteration]
      st = ts if st.nil?
      xts  = ts - st
      fs = c[:failsafephase_flags].strip
      if fs != istate
	istate = fs
	rcd=''
	# Old logs don't have rcData[]
	if c.has_key? :rcdata0
	  rcd = " (#{[c[:rcdata0].strip,c[:rcdata1].strip,c[:rcdata2].strip,c[:rcdata3].strip, ].join(',')})"
	end
	rcx=[c[:rxsignalreceived].strip,c[:rxflightchannelsvalid].strip].join(',')
	if rcd.empty?
	  rcd = " (#{rcx})"
	else
	  rcd << ';' << "(#{rcx})"
	end
	puts ["%9d" % itn, "%6.1f" % ts, "(%6.1f)" % xts, "FAILSAFE=>#{istate}#{rcd}"].join("\t")
      end
      if c[:navstate].to_i != nstate
	if nstate == -1
          hdrs = %w/Iteration Time(s) Elapsed(s)  State FltMode navFlag/
          hdrs << "OSDMode" if (c.has_key? :simplifiedmode)
	  puts hdrs.join("\t")
	end
	nstate = c[:navstate].to_i
	asx = INAV_STATES[inavers][c[:navstate].to_i]
        # Sadly broekn perm ids introduced for 2.x by inav/#3332
        if inavers < "2.7.0"
          if asx == :nav_state_cruise_2d_initialize
            if [:nav_state_rth_initialize, :nav_state_rth_climb_to_safe_alt, :nav_state_rth_head_home].include?(pstate)
              asx = :nav_state_rth_head_home
            end
	  end
        end
        as = asx.to_s
	pstate = asx
	astate = (as) ? "#{as} (#{nstate})" : "State=%d" % nstate
        simplemode= (c.has_key? :simplifiedmode) ? c[:simplifiedmode] : ''
        nfs=""
        nf = c[:navflags].to_i
        if nf & (1<<0) == 0
          nfs << "!AltTrust "
        end
#        if nf & (1<<1) == 0
#          nfs << "!AglTrust "
#        end
        if nf & (1<<2) == 0
          nfs << "!PosTrust "
        end
        if nf & (1<<4) != 0
          nfs << "GPSGLitch "
        end
        if nf & (1<<5) == 0
          nfs << "!HdgTrust"
        end

	puts ["%9d" % itn, "%6.1f" % ts, "(%6.1f)" % xts, astate, c[:flightmodeflags_flags], simplemode,nfs].join("\t")
      end
    end
  end
  puts ["%9d" % itn, "%6.1f" % ts, "(%6.1f)" % xts, "end of log"].join("\t")
end
puts "Disarmed by: #{RDISARMS[disarms[idx-1]]}" if disarms.size >= idx
