#!/usr/bin/ruby

require 'optparse'

## src/main/fc/rc_modes.h

FLAGMON=5
FLAGDAY=15

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
  { boxid: 255, name: "PermIds"}
]


# src/main/io/serial.h

SERIALS = [
  "MSP",
  "GPS",
  "TELEMETRY_FRSKY",
  "TELEMETRY_HOTT",
  "TELEMETRY_LTM",
  "TELEMETRY_SMARTPORT",
  "RX_SERIAL",
  "BLACKBOX",
  "TELEMETRY_MAVLINK",
  "TELEMETRY_IBUS",
  "RCDEVICE",
  "VTX_SMARTAUDIO",
  "VTX_TRAMP",
  "UAV_INTERCONNECT",
  "OPTICAL_FLOW",
  "LOG",
  "RANGEFINDER",
  "VTX_FFPV",
  "SERIALSHOT",
  "TELEMETRY_SIM"
]

MON2MON = {"Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5,
           "Jun" => 6, "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10,
           "Nov" => 11, "Dec" => 12}

force=nil

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

ini=false

ARGF.each do |l|
  bname=''

  if m=l.match(/^# INAV\/\S+\s+(\d+)\.(\d+)\.\d+\s+(\S+)\s+(\d+)\s+(\d+) /)
    if force.nil?
      major = m[1].to_i
      minor = m[2].to_i
      monstr = m[3]
      day = m[4].to_i
      mon = MON2MON[monstr]
      useperm = !(major == 2 && (minor < 5 || (minor == 5 && (mon < FLAGMON || (mon == FLAGMON && day < FLAGDAY)))))
      nametable = PERMNAMES if useperm
      force=true
    end
    puts
    puts l[2..]
    puts "Using #{nametable[-1][:name]} for modes"
    puts
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
      0.upto(19) do |i|
	mask = (1 << i)
	if (fcode & mask) == mask
	  funcs << SERIALS[i]
	end
      end
    end
    puts "UART#{id+1} #{fcode} #{funcs.join(',')}"
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

    if !ini
      ini=true
      puts
    end
    puts "%-20s AUX%d %4d %4d\t(%s)\n" % [bname, chn, min, max, l]
  end
end
