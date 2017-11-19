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
  "PASSTHRU",
  "BEEPER",
  "LEDLOW",
  "LLIGHTS",
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
  "CAMERA CONTROL 3"]

ARGF.each do |l|
  if l.match(/^aux/)
    a=l.chomp.split(' ')
    id = a[1].to_i
    func = a[2].to_i
    chn = a[3].to_i
    min = a[4].to_i
    max = a[5].to_i
    puts "%-20s AUX%d %4d %4d\n" % [BOXNAME[func], chn, min, max]
  end
end
