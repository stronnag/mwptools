#!/usr/bin/ruby

# MIT licence

require 'sequel'
require 'yajl'
require 'optparse'

def create_db dburi
  db = Sequel.connect dburi
  abort unless db

  db.create_table? :meta do
    primary_key :id
    column :dtg, :timestamp
    column :duration, :float
    column :mname, :text
    column :firmware, :text
  end
  db.create_table? :logerrs do
    primary_key :id
    column :errstr, :text
  end
  db.create_table? :logs do
    column :id, :integer
    column :idx, :integer
    column :stamp, :integer
    column :lat, :float
    column :lon, :float
    column :alt, :float
    column :galt, :float
    column :spd, :float
    column :amps, :float
    column :volts, :float
    column :hlat, :float
    column :hlon, :float
    column :vrange, :float
    column :tdist, :float
    column :effic, :float
    column :energy, :float
    column :whkm, :float
    column :whAcc, :float
    column :qval, :float
    column :sval, :float
    column :aval, :float
    column :bval, :float
    column :fmtext, :text
    column :utc, :timestamp
    column :throttle, :integer
    column :cse, :integer
    column :cog, :integer
    column :bearing, :integer
    column :roll, :integer
    column :pitch, :integer
    column :hdop, :integer
    column :ail, :integer
    column :ele, :integer
    column :rud, :integer
    column :thr, :integer
    column :gyro_x, :integer
    column :gyro_y, :integer
    column :gyro_z, :integer
    column :acc_x, :integer
    column :acc_y, :integer
    column :acc_z, :integer
    column :fix, :integer
    column :numsat, :integer
    column :fmode, :integer
    column :rssi, :integer
    column :status, :integer
    column :activewp, :integer
    column :navmode, :integer
    column :hwfail, :integer
    column :windx, :integer
    column :windy, :integer
    column :windz, :integer
  end
  db
end

fn = nil
dbfile=nil
dburi=nil
verbose=false

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-d','--dbfile DBFN'){|o| dbfile=o}
  opt.on('-v','--verbose'){|o| verbose=true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

fn = ARGV[0]
abort "Need a mwp log file" if fn.nil?

if dbfile.nil?
  d = File.basename(fn, ".*")
  dbfile = "#{d}.db"
end
dburi = "sqlite://#{dbfile}"

STDERR.puts "#{fn} => #{dburi}" if verbose

if File.exist? dbfile
  File.delete dbfile
end
db = create_db dburi

st = nil
lt = nil
idx = 0;
id = 0
hlat = nil
hlon = nil
baseutc=nil

ARGV.each do |fn|
  json = File.new(fn, 'r')
  rec={}
  meta = {}
  Yajl::Parser.parse(json, {:symbolize_names => true}) do |o|
    lt = o[:utime]
    case o[:type]
    when "environment"
      idx += 1 # meta id
      st = nil
      lt = nil
      id = 0 # rec no
      hlat = nil
      hlon = nil
      baseutc=nil
      meta[:id] = idx
      meta[:mname] = "No-name"
      meta[:firmware] = "INAV"
      rec = {:status => 0, :tdist => 0}
    when "armed"
      if o[:armed]
        if st.nil?
          st = o[:utime]
        end
        rec[:stamp] = ((o[:utime] - st).to_f*1000*1000).to_i
        rec[:status] |= 1
        rec[:id] = idx
        rec[:utc] = Time.at(o[:utime]).to_s
        if baseutc.nil?
          baseutc = rec[:utc]
          meta[:dtg] = baseutc
        end

        if rec[:cse].nil?
          rec[:cse] = rec[:cog]
        end
        rec[:idx] = id
        id += 1
        STDERR.puts rec if verbose
        db[:logs].insert(rec)
      end
    when "analog2"
      rec[:volts] = o[:voltage]
      rec[:amps] = o[:amps].to_f/100.0
      rec[:rssi] = o[:rssi].to_i*100/1023
    when "status"
      rec[:navmode] = o[:nav_mode].to_i
      rec[:activewp] = o[:wp_number]
      case rec[:navmode]
      when 1,2 # RTH
        rec[:status] |= (13 << 2)
        rec[:fmode] = 13
      when 3,4 # PH
        rec[:status] |= (9 << 2)
        rec[:fmode] = 9
      when 5,6,7 #WP
        rec[:status] |= (10 << 2)
        rec[:fmode] = 10
      when 8,10,11,12,13,14
        rec[:status] = (15 << 2)
        rec[:fmode] = 15
      else
        rec[:fmode] = 0
      end
    # FIXME more fields (mwp update)
    when "raw_gps"
      rec[:utc] = o[:utime]
      rec[:lat] = o[:lat]
      rec[:lon] = o[:lon]
      rec[:galt] = o[:alt].to_f/100
      rec[:fix] = o[:fix]
      rec[:numsat] = o[:numsat]
      rec[:hdop] = o[:hdop]
      rec[:cog] = o[:cse]
      rec[:spd] = o[:spd]
      if rec[:fix] > 0
        if hlat.nil? && hlon.nil?
          hlat = o[:lat]
          hlon = o[:lon]
        end
        rec[:hlat] = hlat
        rec[:hlon] = hlon
      end
    when "comp_gps"
      rec[:vrange] = o[:range]
      rec[:bearing] = o[:bearing]
    when "ltm_xframe"
      if o[:sensorok] != 0
        rec[:hwfail] = true
      end
    when "attitude"
      rec[:cse] = o[:heading]
      rec[:roll] = o[:angx]
      rec[:pitch] = o[:angy]
    when "altitude"
      rec[:alt] = o[:estalt]
    # FIXME vario (mwp update)
    when "ltm_raw_sframe"
      # FIXME more fields (mwp update)
      rec[:status] = o[:flags]
      rec[:volts] = o[:vbat].to_f/1000.0
      rec[:amps] = o[:vcurr].to_f/1000.0
      rec[:rssi] = o[:rssi].to+_i*100/255
    else
      STDERR.puts "Unprocessed #{o[:type]}"
    end
  end
  meta[:duration] = lt - st
  db[:meta].insert(meta)
 end
