#!/usr/bin/ruby

BOXNAME=[
  "ARM",
  "ANGLE",
  "HORIZON",
  "NAV ALTHOLD",
  "HEADING HOLD",
  "HEADFREE",
  "HEADADJ",
  "CAMSTAB",
  "NAV RTH",
  "NAV POSHOLD",
  "MANUAL",
  "BEEPER",
  "LEDLOW",
  "LIGHTS",
  "OSD SW",
  "TELEMETRY",
  "AUTO TUNE",
  "BLACKBOX",
  "FAILSAFE",
  "NAV WP",
  "AIR MODE",
  "HOME RESET",
  "GCS NAV",
  "SURFACE",
  "FLAPERON",
  "TURN ASSIST",
  "NAV LAUNCH",
  "SERVO AUTOTRIM",
  "KILLSWITCH",
  "CAMERA CONTROL 1",
  "CAMERA CONTROL 2",
  "CAMERA CONTROL 3",
  "OSD ALT 1",
  "OSD ALT 2",
  "OSD ALT 3",
  "NAV CRUISE"
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
