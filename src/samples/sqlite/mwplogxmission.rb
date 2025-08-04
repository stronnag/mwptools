#!/usr/bin/ruby

# MIT licence

require 'yajl'
require 'optparse'
require 'nokogiri'

def make_mission fn, wps
  dt = Time.now.strftime("%FT%T%z")
  m = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
    xml.mission {
      xml.mwp ({'generator' => "mwptools/jsonlog2mwxml", 'save-date' => dt})
      wps.each do |w|
        flag = 0
        if w[:no] == wps.length
          flag = 165
        end
        xml.missionitem ({'no' => w[:no], 'action' => "WAYPOINT",
                          'lat' => w[:lat], 'lon' => w[:lon],
                          'alt' => w[:alt].to_i, 'parameter1' => 0,
                          'parameter2' => 0, 'paramater3' => 0, 'flag' => flag})
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

fn = nil
verbose=false

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
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

ARGV.each do |fn|
  json = File.new(fn, 'r')
  rec={}
  wps=[]
  Yajl::Parser.parse(json, {:symbolize_names => true}) do |o|
    lt = o[:utime]
    case o[:type]
    when "armed"
      rec[:armed] = o[:armed]
    when "raw_gps"
      rec[:lat] = o[:lat]
      rec[:lon] = o[:lon]
    when "status"
      if rec[:armed]
        nav_mode = o[:nav_mode].to_i
        wp_number = o[:wp_number]
        navm = (nav_mode > 4 && nav_mode < 8)
        if navm != rec[:navm]
          if  rec[:navm]
            wps << {:no => rec[:wp_number], :lat =>  rec[:lat], :lon =>  rec[:lon], :alt =>  rec[:alt]}
          end
        end
        if navm && wp_number != rec[:wp_number]
          if wp_number != 0
            wps << {:no => rec[:wp_number], :lat =>  rec[:lat], :lon =>  rec[:lon], :alt =>  rec[:alt]}
          end
        end
        rec[:wp_number] = wp_number
        rec[:nav_mode] = nav_mode
        rec[:navm] = navm
      end
    when "altitude"
      rec[:alt] = o[:estalt]
    end
  end
  wps.each_with_index do |m, n,|
    STDERR.puts m
  end
  make_mission nil, wps
end
