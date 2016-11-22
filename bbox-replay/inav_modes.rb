#!/usr/bin/ruby

# Extract heading & gps_course for analysis
# MIT licence

require 'csv'
require 'optparse'
require_relative 'inav_states'

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

STATES.each_with_index { |s,n| puts "#{n} #{s}" }

bbox = (ARGV[0]|| abort('no BBOX log'))
cmd = "blackbox_decode"
cmd << " --index #{idx}"
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
  nstate = -1

  csv.each do |c|
    ts = c[:time_us].to_f / 1000000
    st = ts if st.nil?
    xts  = ts - st
    if c[:navstate].to_i != nstate
      if nstate == -1
	puts %w/Time(s) Elapsed(s)  State/.join("\t")
      end
      nstate = c[:navstate].to_i
      astate = (STATES[nstate]||("State=%d" % nstate))
      puts ["%6.1f" % ts, "(%6.1f)" % xts, astate].join("\t")
    end
  end
end
