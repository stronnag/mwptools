#!/usr/bin/ruby

# Extract heading & gps_course for analysis
# MIT licence

require 'csv'
require 'optparse'
idx = 1
decl = -1.3

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX'){|o|idx=o}
  opt.on('-d','--declination=DEC',Float,'Mag Declination (default -1.3)'){|o|decl=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

bbox = (ARGV[0]|| abort('no BBOX log'))
cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --merge-gps"
cmd << " --declination #{decl}"
cmd << " --simulate-imu"
cmd << " --stdout"
cmd << " " << bbox
IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)
  hdrs = csv.shift
  puts %w/Time(us) navstate gps_speed_ms gps_course heading/.join(",")
  csv.each do |c|
    if c[:navstate].to_i == 1 and
	c[:rccommand3].to_f > 1500 and
	c[:gps_speed_ms].to_f > 2.0
      puts [c[:time_us], c[:navstate], c[:gps_speed_ms].to_f,
	c[:gps_ground_course], c[:heading]].join(",")
    end
  end
end
