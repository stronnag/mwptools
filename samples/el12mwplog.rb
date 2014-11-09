#!/usr/bin/ruby

require 'json'
require 'time'
require 'ap'

# Convert ezgui log to mwp log, for the stupid days when I leave the
# chromebook at home

File.open(ARGV[0]) do |f|
  gsats = 0
  gfix = 0
  lt = 0
  st = 0
  gax = 0
  gay = 0
  f.each do |l|
    l.chomp!
    rec=nil
    case l
    when /Start time:(\S+)\s+/
      logt = $1
    else
      a = l.split(',')
      begin
	dt = "#{logt} #{a[1]}"
	now = Time.parse(dt).to_f
      rescue
	now = nil
      end
      case a[0]
      when  /EMOI/
	rec = {:type => 'init', :utime => now, :mwvers => a[2], :mrtype => a[3],
	  :capability => 0}
      when 'GNAV'
	gfix = a[2].to_i
	gsats = a[3].to_i
	brg = a[4].to_i
	brg = 360 - brg if (brg < 0)
	rec = {:type => "comp_gps", :utime => now, :bearing => brg, :range => a[5].to_i,
	  :update => 1}
      when 'GPAR'
	rec = {:type => "analog", :utime => now, :voltage => a[4].to_f/10.0,
	:amps => 0, :rssi => 0, :power => 0}
      when 'GATT'
	gax = a[2].to_f
	gay = a[3].to_f
      when 'EALT'
	alt = a[2].to_f
	vario = a[3].to_i / 10.0
	rec = {:type => "altitude", :utime => now, :estalt => alt, :vario => vario}
      when 'EGPS'
	lat = a[2].to_f /  10000000.0
	lon = a[3].to_f /  10000000.0
	alt = a[4].to_i
	spd = a[5].to_f / 100.0
	cse = a[6].to_f / 10;
	rec = {:type => "raw_gps", :utime => now, :lat => lat, :lon => lon,
	  :cse => cse ,:spd => spd, :alt => alt, :fix => gfix , :numsat => gsats}
      when 'GRAW'
      when 'GMAG'
	hdr = a[5].to_i
	rec = {:type => "attitude", :utime => now, :angx => gax, :angy => gay,
	  :heading => hdr}
      when 'ENAS'
	rec = {:type => "status", :utime => now, :gps_mode => a[2].to_i,
	  :nav_mode => a[3].to_i, :action => a[4].to_i, :wp_number => a[5].to_i,
	  :nav_error => a[6].to_i, :target_bearing => a[7].to_i}
      when 'ERAD'
	rec = {:type => "radio", :utime => now, :rxerrors => a[2].to_i,
	  :fixed_errors => a[3].to_i, :localrssi => a[4].to_i, :remrssi => a[5].to_i,
	  :txbuf => a[6].to_i, :noise => a[7].to_i, :remnoise => a[8].to_i}
      end
    end
    if rec
      puts rec.to_json
      if now and now.to_i != lt
	st = lt if st.zero?
	lt = now.to_i
	rec = {:type => "armed", :utime => now, :armed => true, :duration => (lt - st)}
	puts rec.to_json
      end
    end
  end
end
