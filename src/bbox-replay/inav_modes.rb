#!/usr/bin/ruby

# Analyse iNav mode changes
# MIT licence

require 'csv'
require 'optparse'

idx = 1
verbose = nil

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX',Integer){|o|idx=o}
  opt.on('-v','--verbose'){verbose=true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

bbox = (ARGV[0]|| abort('no BBOX log'))

gitinfos=[]
disarms=[]

File.open(bbox,'rb') do |f|
  f.each do |l|
    if m = l.match(/^H Firmware revision:(.*)$/)
      gitinfos << m[1]
    elsif m = l.match(/End of log \(disarm reason:(\d+)/)
      disarms << m[1].to_i
    end
  end
end

gitinfo = gitinfos[idx - 1]

abort "Doesn't look like Blackbox (#{bbox})" unless gitinfo

iv=nil
if m=gitinfo.match(/^INAV (\d{1})\.(\d{1})\.(\d{1}) \(([0-9A-Fa-f]{7,})\) (\S+)/)
  iv = [m[1],m[2],m[3]].join('.')
end

STDERR.puts "iNav version = #{iv}" if verbose

puts "#{File.basename(bbox)}: #{gitinfos[idx-1] if gitinfos.size >= idx}"

cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --stdout"
cmd << " 2>#{IO::NULL}"
cmd << " " << bbox

IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)

  nhdr=false
  itn=0
  nmode = ""
  st = nil
  xts=nil
  ts=nil

  csv.each do |c|
    if  nhdr == false
      nhdr = true
    else
      ts = c[:time_us].to_f / 1000000
      itn = c[:loopiteration]
      st = ts if st.nil?
      xts  = ts - st
      if c[:flightmodeflags_flags] != nmode
	if nmode == ""
	  puts %w/Iteration Time(s) Elapsed(s) Modes/.join("\t")
	end
        nmode = c[:flightmodeflags_flags]
	puts ["%9d" % itn, "%6.1f" % ts, "(%6.1f)" % xts, nmode].join("\t")
      end
    end
  end
  puts ["%9d" % itn, "%6.1f" % ts, "(%6.1f)" % xts, "end of log"].join("\t")
end
