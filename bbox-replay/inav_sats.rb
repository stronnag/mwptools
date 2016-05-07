#!/usr/bin/ruby

# Extract heading & gps_course for analysis
# MIT licence

require 'csv'
require 'optparse'

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
IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)
  hdrs = csv.shift
  st = nil
  nsats = 0

  puts %w/Time Sats Hdop/.join("\t")
  csv.each do |c|
    ts = c[:time_s].to_f
    st = ts if st.nil?
    ts -= st
    csats = c[:gps_numsat].to_i
    if csats != nsats
      nsats = csats
      puts ["%.6f" % ts, nsats, c[:gps_hdop].to_f/100.0].join("\t")
    end
  end
end
