#!/usr/bin/ruby

# Extract sat coverage for analysis
# MIT licence

require 'csv'
require 'optparse'
include Math

RAD = 0.017453292

def get_vas(gspd, gcse, wspd, wdirn)
  # Wind direction is "from" whereas Course is "to"
  wdirn = (wdirn + 180) % 360
  wdiff = gcse - wdirn
  if (wdiff < 0)
    wdiff += 360
  end
  vas = gspd - wspd * cos(wdiff*RAD)
  return [vas, wdiff]
end


def calc_wind(w_x, w_y)
  angle = atan2(w_y, w_x) / RAD
  angle += 360 if angle < 0
  angle = angle.to_i
  w_cms = sqrt(w_x*w_x + w_y*w_y)
  w_ms = w_cms / 100
  w_kts = (w_ms*3600/1852).round
  return [angle, w_ms, w_kts]
end

idx = 1

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX'){|o|idx=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

bbox = (ARGV[0]|| abort('no BBOX log'))
cmd = "blackbox_decode 2>#{IO::NULL}"
cmd << " --index #{idx}"
cmd << " --merge-gps"
cmd << " --unit-frame-time s"
cmd << " --stdout"
cmd << " " << bbox

IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)
  hdrs = nil
  last_x = 0
  last_y = 0

  ni = 0
  ax = 0
  ay = 0
  w_ms = nil
  w_kts = nil
  angle = nil

  puts %w/Time Dirn ws(m\/s) GSpd GCse Vas Wdiff ws(kts) alt(m)/.join("\t")
  csv.each do |c|
    if hdrs
      w_x = c[:wind0].to_f
      w_y = c[:wind1].to_f
      alt = (c[:navpos2].to_f / 100).round
      gspd = c[:gps_speed_ms].to_f
      gcse = c[:gps_ground_course].to_i
      if  !(w_x == last_x && w_y == last_y)
        angle, w_ms, w_kts = calc_wind(w_x, w_y)
        ax += w_x
        ay += w_y
        ni += 1
        last_x = w_x
        last_y = w_y
        vas,wdiff = get_vas(gspd, gcse, w_ms, angle)
        ts = c[:time_s].to_f
	puts "%.3f\t%.0f\t%.1f\t%.1f\t%.0f\t%.1f\t%.0f\t%.1f\t%.0f\n" %
             [ts,angle,w_ms, gspd,gcse,vas, wdiff, w_kts,alt]
      end
    else
      hdrs = c
    end
  end
  ax = ax / ni
  ay = ay / ni
  angle, w_ms, w_kts = calc_wind(ax, ay)
  STDERR.puts "** Average spd %.1f m/s, %.1f kts dirn %.1f\n" % [w_ms, w_kts, angle]
end
