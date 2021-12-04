#!/usr/bin/ruby

# Extract sat coverage for analysis
# MIT licence

require 'csv'
require 'optparse'
include Math

RAD = 0.017453292

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
cmd = "blackbox_decode 2</dev/null"
cmd << " --index #{idx}"
cmd << " --merge-gps"
cmd << " --unit-frame-time s"
cmd << " --stdout"
cmd << " " << bbox

st = nil
IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)
  hdrs = nil
  last_a = -1
  last_s = 9999

  puts %w/Time Dirn m\/s knots alt(m)/.join("\t")
  csv.each do |c|
    if hdrs
      w_x = c[:wind0].to_f
      w_y = c[:wind1].to_f
      alt = (c[:navpos2].to_f / 100).round
      angle = atan2(w_y, w_x) / RAD
      angle += 360 if angle < 0
      angle = angle.to_i
      w_cms = sqrt(w_x*w_x + w_y*w_y)
      w_ms = w_cms / 100
      w_kts = (w_ms*3600/1852).round
      if angle != last_a or w_kts != last_s
	ts = c[:time_s].to_f
	puts "%.3f\t%.0f\t%.1f\t%.1f\t%.0f\n" % [ts,angle,w_ms, w_kts,alt]
	last_a = angle
	last_s = w_kts
      end
    else
      hdrs = c
    end
  end
end
