#!/usr/bin/ruby

## src/main/fc/rc_modes.h

BOXNAME=[
  "ARM", #  0
  "ANGLE", #  1
  "HORIZON", #  2
  "NAV ALTHOLD", #  3
  "HEADINGHOLD", #  4
  "HEADFREE", #  5
  "HEADADJ", #  6
  "CAMSTAB", #  7
  "NAV RTH", #  8
  "NAV POSHOLD", #  9
  "MANUAL", #  10
  "BEEPER ON", #  11
  "LEDLOW", #  12
  "LIGHTS", #  13
  "NAV LAUNCH", #  14
  "OSD", #  15
  "TELEMETRY", #  16
  "BLACKBOX", #  17
  "FAILSAFE", #  18
  "NAV WP", #  19
  "AIRMODE", #  20
  "HOME RESET", #  21
  "GCS NAV", #  22
  "KILLSWITCH", #  23
  "SURFACE", #  24
  "FLAPERON", #  25
  "TURN ASSIST", #  26
  "AUTOTRIM", #  27
  "AUTOTUNE", #  28
  "CAMERA1", #  29
  "CAMERA2", #  30
  "CAMERA3", #  31
  "OSDALT1", #  32
  "OSDALT2", #  33
  "OSDALT3", #  34
  "CRUISE", #  35
  "BRAKING", #  36
]

ARGF.each do |l|
  bname=''
  if l.match(/^aux/)
    a=l.chomp.split(' ')
    id = a[1].to_i
    func = a[2].to_i
    chn = a[3].to_i
    min = a[4].to_i
    max = a[5].to_i
    if func < BOXNAME.size
      bname = BOXNAME[func]
    else
      bname = "PermID #{func}"
    end
    puts "%-20s AUX%d %4d %4d\n" % [bname, chn, min, max]
  end
end
