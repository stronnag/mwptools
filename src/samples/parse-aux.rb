#!/usr/bin/ruby

require 'optparse'

## src/main/fc/rc_modes.h

FLAGMON=5
FLAGDAY=5

BOXNAMES = [
  { permid: 0, name: "ARM"},	# 0
  { permid: 1, name: "ANGLE"},	# 1
  { permid: 2, name: "HORIZON"},	# 2
  { permid: 3, name: "NAV ALTHOLD"},	# 3
  { permid: 5, name: "HEADING HOLD"},	# 4
  { permid: 6, name: "HEADFREE"},	# 5
  { permid: 7, name: "HEADADJ"},	# 6
  { permid: 8, name: "CAMSTAB"},	# 7
  { permid: 10, name: "NAV RTH"},	# 8
  { permid: 11, name: "NAV POSHOLD"},	# 9
  { permid: 12, name: "MANUAL"},	# 10
  { permid: 13, name: "BEEPER"},	# 11
  { permid: 15, name: "LEDLOW"},	# 12
  { permid: 16, name: "LIGHTS"},	# 13
  { permid: 36, name: "NAV LAUNCH"},	# 14
  { permid: 19, name: "OSD SW"},	# 15
  { permid: 20, name: "TELEMETRY"},	# 16
  { permid: 26, name: "BLACKBOX"},	# 17
  { permid: 27, name: "FAILSAFE"},	# 18
  { permid: 28, name: "NAV WP"},	# 19
  { permid: 29, name: "AIR MODE"},	# 20
  { permid: 30, name: "HOME RESET"},	# 21
  { permid: 31, name: "GCS NAV"},	# 22
  { permid: 38, name: "KILLSWITCH"},	# 23
  { permid: 33, name: "SURFACE"},	# 24
  { permid: 34, name: "FLAPERON"},	# 25
  { permid: 35, name: "TURN ASSIST"},	# 26
  { permid: 37, name: "SERVO AUTOTRIM"},	# 27
  { permid: 21, name: "AUTO TUNE"},	# 28
  { permid: 39, name: "CAMERA CONTROL 1"},	# 29
  { permid: 40, name: "CAMERA CONTROL 2"},	# 30
  { permid: 41, name: "CAMERA CONTROL 3"},	# 31
  { permid: 42, name: "OSD ALT 1"},	# 32
  { permid: 43, name: "OSD ALT 2"},	# 33
  { permid: 44, name: "OSD ALT 3"},	# 34
  { permid: 45, name: "NAV CRUISE"},	# 35
  { permid: 46, name: "MC BRAKING"},	# 36
  { permid: 47, name: "USER1"},	# 37
  { permid: 48, name: "USER2"},	# 38
  { permid: 32, name: "FPV ANGLE MIX"},	# 39
  { permid: 49, name: "LOITER CHANGE"},	# 40
  { permid: 50, name: "MSP RC OVERRIDE"},	# 41
  { name: "USER3", permid: 57},
  { name: "USER4", permid: 58},
  { name: "LOITER CHANGE",     permid: 49 },
  { name: "MSP RC OVERRIDE",   permid: 50 },
  { name: "PREARM",            permid: 51 },
  { name: "TURTLE",            permid: 52 },
  { name: "NAV CRUISE", permid: 53 },
  { name: "AUTO LEVEL TRIM",   permid: 54 },
  { name: "WP PLANNER",        permid: 55 },
  { name: "SOARING",           permid: 56 },
  { name: "MISSION CHANGE",    permid: 59 },
  { name: "BEEPER MUTE",       permid: 60 },
  { name: "MULTI FUNCTION",    permid: 61 },
  { name: "MIXER PROFILE 2",   permid: 62 },
  { name: "MIXER TRANSITION",  permid: 63 },
  { name: "ANGLE HOLD",        permid: 64 },
  { permid: 255, name: "BoxIds"}
]

PERMNAMES = [
  { boxid: 0, name: "ARM"},	# 0
  { boxid: 1, name: "ANGLE"},	# 1
  { boxid: 2, name: "HORIZON"},	# 2
  { boxid: 3, name: "NAV ALTHOLD"},	# 3
  {},		# 4
  { boxid: 4, name: "HEADING HOLD"},	# 5
  { boxid: 5, name: "HEADFREE"},	# 6
  { boxid: 6, name: "HEADADJ"},	# 7
  { boxid: 7, name: "CAMSTAB"},	# 8
  {},		# 9
  { boxid: 8, name: "NAV RTH"},	# 10
  { boxid: 9, name: "NAV POSHOLD"},	# 11
  { boxid: 10, name: "MANUAL"},	# 12
  { boxid: 11, name: "BEEPER"},	# 13
  {},		# 14
  { boxid: 12, name: "LEDLOW"},	# 15
  { boxid: 13, name: "LIGHTS"},	# 16
  {},		# 17
  {},		# 18
  { boxid: 15, name: "OSD SW"},	# 19
  { boxid: 16, name: "TELEMETRY"},	# 20
  { boxid: 28, name: "AUTO TUNE"},	# 21
  {},		# 22
  {},		# 23
  {},		# 24
  {},		# 25
  { boxid: 17, name: "BLACKBOX"},	# 26
  { boxid: 18, name: "FAILSAFE"},	# 27
  { boxid: 19, name: "NAV WP"},	# 28
  { boxid: 20, name: "AIR MODE"},	# 29
  { boxid: 21, name: "HOME RESET"},	# 30
  { boxid: 22, name: "GCS NAV"},	# 31
  { boxid: 39, name: "FPV ANGLE MIX"},	# 32
  { boxid: 24, name: "SURFACE"},	# 33
  { boxid: 25, name: "FLAPERON"},	# 34
  { boxid: 26, name: "TURN ASSIST"},	# 35
  { boxid: 14, name: "NAV LAUNCH"},	# 36
  { boxid: 27, name: "SERVO AUTOTRIM"},	# 37
  { boxid: 23, name: "KILLSWITCH"},	# 38
  { boxid: 29, name: "CAMERA CONTROL 1"},	# 39
  { boxid: 30, name: "CAMERA CONTROL 2"},	# 40
  { boxid: 31, name: "CAMERA CONTROL 3"},	# 41
  { boxid: 32, name: "OSD ALT 1"},	# 42
  { boxid: 33, name: "OSD ALT 2"},	# 43
  { boxid: 34, name: "OSD ALT 3"},	# 44
  { boxid: 35, name: "NAV CRUISE"},	# 45
  { boxid: 36, name: "MC BRAKING"},	# 46
  { boxid: 37, name: "USER1"},	# 47
  { boxid: 38, name: "USER2"},	# 48
  { boxid: 40, name: "LOITER CHANGE"},	# 49
  { boxid: 41, name: "MSP RC OVERRIDE"},	# 50
  { boxid: 42, name: "PREARM"},
  { boxid: 43, name: "TURTLE"},
  { boxid: 44, name: "NAVCRUISE"},
  { boxid: 45, name: "AUTOLEVEL"},
  { name: "PLANWPMISSION", boxid: 46},
  { name: "SOARING", boxid: 47},
  { name: "USER3", boxid: 48},
  { name: "USER4", boxid: 49},
  { name: "CHANGEMISSION", boxid: 50},
  { name: "BEEPERMUTE", boxid: 51},
  { name: "MULTIFUNCTION", boxid: 52},
  { name: "MIXERPROFILE", boxid: 53},
  { name: "MIXERTRANSITION", boxid: 54},
  { name: "ANGLEHOLD", boxid: 55},
  { boxid: 255, name: "PermIds"}
]


# src/main/io/serial.h

SERIALS = [
  "MSP",                # 0
  "GPS",                # 1
  "TELEMETRY_FRSKY",    # 2
  "TELEMETRY_HOTT",	# 3
  "TELEMETRY_LTM",	# 4
  "TELEMETRY_SMARTPORT",# 5
  "RX_SERIAL", 		# 5
  "BLACKBOX", 		# 7
  "TELEMETRY_MAVLINK",	# 8
  "TELEMETRY_IBUS",	# 9
  "RCDEVICE",		# 10
  "VTX_SMARTAUDIO",	# 11
  "VTX_TRAMP",		# 12
  "UAV_INTERCONNECT",	# 13, aka unused
  "OPTICAL_FLOW",	# 14
  "LOG",		# 15
  "RANGEFINDER",	# 16
  "VTX_FFPV",		# 17
  "SERIALSHOT",		# 18
  "TELEMETRY_SIM",	# 19
  "FRSKY_OSD",		# 20
  "DJI_HD_OSD",		# 21
  "SERVO_SERIAL",	#22
  "TELEMETRY_SMARTPORT_MASTER", # 23
  "IMU2", 		#24
  "HDZERO",             #25
]

MON2MON = {"Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5,
           "Jun" => 6, "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10,
           "Nov" => 11, "Dec" => 12}

SMIXES = [
  "Stabilised ROLL",
  "Stabilised PITCH",
  "Stabilised YAW",
  "Stabilised THROTTLE",
  "RC ROLL",
  "RC PITCH",
  "RC YAW",
  "RC THROTTLE",
  "RC channel 5",
  "RC channel 6",
  "RC channel 7",
  "RC channel 8",
  "GIMBAL PITCH",
  "GIMBAL ROLL",
  "FEATURE FLAPS",
  "RC channel 9",
  "RC channel 10",
  "RC channel 11",
  "RC channel 12",
  "RC channel 13",
  "RC channel 14",
  "RC channel 15",
  "RC channel 16",
  "Stabilized ROLL+",
  "Stabilized ROLL-",
  "Stabilized PITCH+",
  "Stabilized PITCH-",
  "Stabilized YAW+",
  "Stabilized YAW-",
  "MAX"
]

force=:permids

ARGV.options do |opt|
  opt.on('','--force-mode=[MODES]',[:boxids,:permids], "force aux modes (boxids,permids)") {|o|force=o}
  opt.on('-?', "--help", "Show this message") {puts opt; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

if force == :permids
  nametable = PERMNAMES
else
  nametable = BOXNAMES
end

inis=false
inia=false
iniv = false
auxs=[]

ARGF.each do |l|
  bname=''
  if m=l.match(/^# INAV\/\S+\s+(\d+)\.(\d+)\.\d+\s+(\S+)\s+(\d+)\s+(\d+) /)
    if force.nil?
      major = m[1].to_i
      minor = m[2].to_i
      monstr = m[3]
      day = m[4].to_i
      mon = MON2MON[monstr]
      useperm = !(major == 1 ||(major == 2 && (minor < 5 || (minor == 5 && (mon < FLAGMON || (mon == FLAGMON && day < FLAGDAY))))))
      nametable = PERMNAMES if useperm
      force=true
    end
    puts
    puts l[2..]
    puts "Using #{nametable[-1][:name]} for modes"
    puts
  end

  if l.match (/^smix/)
    l.chomp!
    a=l.split(' ')
    if a.size > 5
      id = a[1].to_i
      sidx = a[2].to_i
      iid = a[3].to_i
      wid = a[4].to_i
      spd = a[5].to_i
      lid = a[6].to_i
      idstr = SMIXES[iid]
      puts "SMIX#{id} #{sidx} #{idstr} #{wid}"
    end
  end

  if l.match (/^serial/)
    l.chomp!
    a=l.split(' ')
    id = a[1].to_i
    fcode = a[2].to_i
    funcs=[]
    if fcode == 0
      funcs << "Unused"
    else
      0.upto(SERIALS.size) do |i|
	mask = (1 << i)
	if (fcode & mask) == mask
	  funcs << SERIALS[i]
	end
      end
    end
    if !inis
      inis=true
      puts
    end
    if id /10 == 2 # VCP
      puts "VCP    %5d %s" % [fcode, funcs.join(',')]
    elsif id / 10 == 3 # SS
      puts "SSer%2d %5d %s" % [(id+1) % 10, fcode, funcs.join(',')]
    else
      puts "UART%2d %5d %s" % [id+1, fcode, funcs.join(',')]
    end
  end

  if l.match(/^aux/)
    l.chomp!
    a=l.split(' ')
    id = a[1].to_i
    func = a[2].to_i
    chn = a[3].to_i
    min = a[4].to_i
    max = a[5].to_i
    next if min == max && max == 900
    if func < nametable.size
      bname = nametable[func][:name]
    else
      bname = "Unknown"
    end

    if !inia
      inia=true
      puts
    end
    auxs << "%-20s CHAN%2d %4d %4d\t(%s)\n" % [bname, chn+5, min, max, l]
  end
end

if iniv || force != nil
  auxs.sort{|a,b| a[21..-1] <=> b[21..-1]}.each{|a| puts a}
else
  puts "*********** No Version or --force=IDTYPE **************"
end
