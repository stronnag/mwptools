#!/usr/bin/ruby

# Extract GPS 'zero satellite' reports from BBLogs for analysis
# MIT licence

require 'csv'
require 'optparse'

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [files ...]"
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

nzero = nfile = nlog = 0
ARGV.each do |bbox|
  idx = 1
  vbox = true
  nfile += 1
  while vbox do
    cmd = "blackbox_decode"
    cmd << " --index #{idx}"
    cmd << " --stdout"
    cmd << " --merge-gps"
    cmd << " --unit-frame-time s"
    cmd << " 2>/dev/null " << bbox

    IO.popen(cmd,'r') do |p|
      csv = CSV.new(p, :col_sep => ",",
		    :headers => :true,
		    :header_converters =>
		    ->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		    :return_headers => true)
      hdrs = csv.shift
      if hdrs == nil
	vbox = false
	break
      end
      st = nil
      frec = nil
      pprec = nil
      zerosat = false
      prec = {:gps_numsat => -1}
      csv.each do |c|

	ts = c[:time_s].to_f
	st = ts if st.nil?
	rt = ts - st
	nsat = c[:gps_numsat].to_i
	os = prec[:gps_numsat]
	crec = {
	  :gps_numsat => nsat,
	  :gps_fixtype =>  c[:gps_fixtype].to_i,
	  :gps_hdop => c[:gps_hdop].to_i,
	  :et => rt
	}
	if nsat == 0 and os > 0
	  frec = {
	    :gps_numsat => nsat,
	    :gps_fixtype =>  c[:gps_fixtype].to_i,
	    :gps_hdop => c[:gps_hdop].to_i,
	    :et => rt
	  }
	  pprec = prec
	elsif !frec.nil? and nsat > 0 and rt > 0
	  if nsat > 5
	    if zerosat == false
	      puts "****** #{bbox} index = #{idx}"
	      zerosat = true
	    end
	    nzero += 1
	    set = rt - frec[:et]
	    sst = "%.2f" % [set]
	    puts " GPS 0-sat event of #{sst}s duration"
	    puts " Before : numsats=%d, fixtype=%d, hdop=%d, time=%.2fs\n" %
	      [pprec[:gps_numsat], pprec[:gps_fixtype], pprec[:gps_hdop], pprec[:et]]
	    puts " Event : numsats=%d, fixtype=%d, hdop=%d, time=%.2fs\n" %
	      [frec[:gps_numsat], frec[:gps_fixtype], frec[:gps_hdop], frec[:et]]
	    puts " Resume: numsats=%d, fixtype=%d, hdop=%d, time=%.2fs\n" %
	      [crec[:gps_numsat], crec[:gps_fixtype], crec[:gps_hdop], crec[:et]]
	  end
	  frec = nil
	  pprec = nil
	end
	prec = crec
      end
      nlog += 1
      idx += 1
    end
  end
end
puts "Files #{nfile}, flight logs #{nlog}, zero-sat records #{nzero}"
