#!/usr/bin/ruby

# Extract sat coverage for analysis
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

def fmtstr ts, sats, hdop, epv, eph, eeok
  stat = eeok ? '' : '*'
  puts ["%.1f" % ts, sats, hdop/100, epv/100, eph/100,stat].join("\t")
end

bbox = (ARGV[0]|| abort('no BBOX log'))
cmd = "blackbox_decode 2>#{IO::NULL}"
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
  csv.shift
  nsats = -1

  puts %w/Time Sats Hdop EPV EPH Status/.join("\t")
  leeok = eeok = true
  csv.each do |c|
    ts = c[:time_s].to_f
    st = ts if st.nil?
    ts -= st
    s = nil
    csats = c[:gps_numsat].to_i
    epv = c[:gps_epv].to_f
    eph = c[:gps_eph].to_f
    if epv > 1000 or eph > 1000
      eeok = false
    else
      eeok = true
    end
    if csats != nsats
      tok = eeok
      if csats == 0 && nsats > 0 # for momentary failure
	tok = false
      else
      end
      s= fmtstr ts, csats, c[:gps_hdop].to_f, epv, eph, tok
      nsats = csats
    end
    if eeok != leeok
      s = fmtstr ts, csats, c[:gps_hdop].to_f, epv, eph, eeok
      leeok = eeok
    end
    puts(s) if s
  end
end
exit (st.nil?) ? 255 : 0
