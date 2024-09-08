#!/usr/bin/ruby

require 'csv'
require 'nokogiri'
require 'optparse'

def make_mission fn, wps
  dt = Time.now.strftime("%FT%T%z")
  m = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
    xml.mission {
      xml.mwp ({'generator' => "mwptools/cli2mwxml", 'save-date' => dt})
      wps.each do |w|
        xml.missionitem ({'no' => w[:no], 'action' => "WAYPOINT",
                          'lat' => w[:lat], 'lon' => w[:lon],
                          'alt' => w[:ealt].to_i, 'parameter1' => 0,
                          'parameter2' => 0, 'paramater3' => 0})
      end
    }
  end
  if fn.nil? or fn.empty? or fn == "-"
    fn = STDOUT.fileno
  end
  File.open(fn,"w") do |fh|
    fh.puts m.to_xml
  end
end

idx = 1
outfn=nil
verbose=nil

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] BBL_log"
  opt.on('-i','--index=IDX', Integer){|o|idx=o}
  opt.on('-o','--output=FILE'){|o|outfn=o}
  opt.on('-v','--verbose'){verbose=true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

ms = []

cmd = "blackbox_decode"
cmd << " --merge-gps"
cmd << " --stdout"
cmd << " --index #{idx}"
cmd << " 2>#{IO::NULL}"
cmd << " \"#{ARGV[0]}\""

hdrline = IO.popen(cmd,'rt') {|f| f.readline}

IO.popen(cmd,'rt') do |pipe|
  csv = CSV.new(pipe,
                :col_sep => ",",
                :headers => :true,
                :header_converters =>
                ->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
                :return_headers => true)
  hdrs=nil
  lwpno = 0
  lnavm = 0
  navm = 0
  wpno = 0
  csv.each do |r|
    if hdrs == nil
      csv.headers()
      hdrs = true
    else
      wpno = r[:activewpnumber].to_i
      navflags = r[:flightmodeflags_flags].split("|")
      if navflags.include? "NAVWP"
        navm = 1
      else
        navm = 0
      end
      lat = r[:gps_coord0].to_f
      lon = r[:gps_coord1].to_f
      alt = r[:gps_altitude].to_f
      aalt = r[:navpos2].to_f
      if navm != lnavm
        if lnavm == 1
          STDERR.puts "MODE: m #{lnavm} #{navm} wp #{lwpno} #{wpno} #{lat} #{lon} #{alt} #{aalt}" if verbose
          ms << { :no => lwpno, :lat => lat, :lon => lon, :galt => alt, :ealt => aalt/100}
        end
      end
      if lwpno != wpno
        STDERR.puts "WPNO: m #{lnavm} #{navm} wp #{lwpno} #{wpno} #{lat} #{lon} #{alt} #{aalt}" if verbose
        if lwpno != 0
          ms << { :no => lwpno, :lat => lat, :lon => lon, :galt => alt, :ealt => aalt/100}
        end
      end
      lwpno = wpno
      lnavm = navm
    end
  end
  if verbose
    ms.each do |m|
      STDERR.puts m.inspect
    end
  end
  make_mission outfn,ms
end
