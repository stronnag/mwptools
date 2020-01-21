#!/usr/bin/ruby

## src/main/fc/rc_modes.h

BOXNAME=[
  "ARM", #  0
  "ANGLE", #  1
  "HORIZON", #  2
  "NAVALTHOLD", #  3
  "HEADINGHOLD", #  4
  "HEADFREE", #  5
  "HEADADJ", #  6
  "CAMSTAB", #  7
  "NAVRTH", #  8
  "NAVPOSHOLD", #  9
  "MANUAL", #  10
  "BEEPERON", #  11
  "LEDLOW", #  12
  "LIGHTS", #  13
  "NAVLAUNCH", #  14
  "OSD", #  15
  "TELEMETRY", #  16
  "BLACKBOX", #  17
  "FAILSAFE", #  18
  "NAVWP", #  19
  "AIRMODE", #  20
  "HOMERESET", #  21
  "GCSNAV", #  22
  "KILLSWITCH", #  23
  "SURFACE", #  24
  "FLAPERON", #  25
  "TURNASSIST", #  26
  "AUTOTRIM", #  27
  "AUTOTUNE", #  28
  "CAMERA1", #  29
  "CAMERA2", #  30
  "CAMERA3", #  31
  "OSDALT1", #  32
  "OSDALT2", #  33
  "OSDALT3", #  34
  "NAVCRUISE", #  35
  "BRAKING", #  36
  "USER1", #  37
  "USER2", #  38
  "FPVANGLEMIX", #  39
  "LOITERDIRCHN", #  40
  "MSPRCOVERRIDE", # 41,
  "ACCCOMP"       # 42
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

ini=false
ARGF.each do |l|
  bname=''

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
    if func < BOXNAME.size
      bname = BOXNAME[func]
    else
      bname = "PermID #{func}"
    end
    if !ini
      ini=true
      puts
    end
    puts "%-20s AUX%d %4d %4d\t(%s)\n" % [bname, chn, min, max, l]
  end
end
