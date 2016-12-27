#!/usr/bin/ruby
require 'sequel'
require 'yajl'
require 'nokogiri'
require 'optparse'
#require 'ap'
# MIT licence

# -*- coding: utf-8 -*-

def recins db,rec,mid
  if rec and rec.size > 0
    rec[:stamp] = Time.at rec[:utime]
    rec.delete(:type)
    rec.delete(:utime)
    rec[:mid] = mid
    db[:reports].insert(rec)
  end
end

title=nil
dburi='sqlite://f.sqlite'

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-t','--title NAME'){|o| title=o}
  opt.on('-d','--dburi DBURI'){|o| dburi=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

abort "Usage: m2x.rb FILE\n" unless (file = ARGV[0])

db = Sequel.connect dburi
abort unless db
db.create_table? :missions do
  primary_key :id
  column :title, :text
  column :start, :timestamp
  column :end, :timestamp
  column :mwvers, :string
  column :mrtype, :integer
  column :capability, :integer
  column :fctype, :integer
end

db.create_table? :reports do
  primary_key :id
  column :mid,:integer
  column :stamp, :timestamp
  column :estalt, :float
  column :vario, :float
  column :gps_mode, :integer
  column :nav_mode, :integer
  column :action, :integer
  column :wp_number, :integer
  column :nav_error, :integer
  column :target_bearing, :integer
  column :lat, :float
  column :lon, :float
  column :cse, :float
  column :spd, :float
  column :alt, :float
  column :fix, :integer
  column :numsat, :integer
  column :bearing, :integer
  column :range, :integer
  column :update, :integer
  column :voltage, :float
  column :power, :float
  column :rssi, :float
  column :amps, :float
  column :angx, :float
  column :angy, :float
  column :heading, :integer
  column :duration, :integer
  column :sensors, :integer
  column :armed, :boolean
  column :rxerrors, :integer
  column :fixed_errors, :integer
  column :localrssi, :integer
  column :remrssi,:integer
  column :txbuf,:integer
  column :noise,:integer
  column :remnoise,:integer
  column :wp_no,:integer
  column :wp_lat,:float
  column :wp_lon,:float
  column :wp_alt,:float
  column :flags,:integer
end
ln=0
otitle=title
ARGV.each do |fn|
  title = fn if otitle.nil?
  doc=nil
  json = File.new(fn, 'r')
  lt=0
  st = 0
  rec=nil
  valid = false
  db.transaction do
    mid = db[:missions].insert({:title => title})
    title=nil
    Yajl::Parser.parse(json, {:symbolize_names => true}) do |o|
      ln += 1
      $o = o
      keys = o.keys
      keys.each do |k|
	if k.class == String
	  o[k.to_sym] = o[k]
	  o.delete(k)
	end
      end

      if o[:type] == 'init'
	db[:missions].where(:id => mid).update({:title => o[:mission],
						:mwvers => o[:mwvers],
						:mrtype => o[:mrtype],
						:capability => o[:capability]})
      else
	next if o[:type] == 'ltm_raw_sframe'
	if o[:type].match(/^mavlink/)
	  o.delete(:time_usec)
	  case o[:type]
	  when "mavlink_gps_raw_int"
	    o[:lat] /= 10000000.0
	    o[:lon] /= 10000000.0
	    o[:alt] /= 1000.0
	    o[:type] = 'raw_gps'
	    o[:spd] = o[:vel]/100.0
	    o[:fix] = o[:fix_type]
	    o[:numsat] = o[:satellites_visible]
	    [:vel, :eph, :epv, :cog, :fix_type, :satellites_visible].each do |k|
	      o.delete(k)
	    end
	  when "mavlink_attitude"
	    ax = o[:roll]
	    ay = o[:pitch]
	    keys = o.keys
	    keys.each { |k| o.delete(k) }
	    o[:angx] = ax
	    o[:angy] = ay
	  when"mavlink_vfr_hud"
	    estalt = o[:alt]
	    vario = o[:climb]
	    keys = o.keys
	    keys.each { |k| o.delete(k) }
	    o[:estalt] = estalt
	    o[:vario] = vario
	  when "mavlink_sys_status"
	    v = o[:voltage_battery]/1000.0
	    keys = o.keys
	    keys.each { |k| o.delete(k) }
	    o[:voltage] = v
	  else
	    next
	  end
	end
	next if o[:type] == 'wp_poll' and !o.has_key? :wp_lat
	if  o[:type] == 'armed'
	  ot = o[:utime].to_i
	  st = ot if lt.zero?
	  if rec and valid
	    recins db,rec,mid
	    valid = false
	  end
	  lt = ot
	  rec = o
	else
	  valid = true if o[:type] == 'raw_gps'
	  if rec
	    rec.merge!(o)
	  end
	end
	if valid
	  recins db,rec,mid
	  valid  = false
	  rec = {}
	end
      end
    end
    db[:missions].where(:id => mid).update({:start => Time.at(st),
					     :end => Time.at(lt)})
  end
end
