#!/usr/bin/env ruby


require 'uart'
require 'socket'
require 'uri'
require 'optparse'
require 'time'
require_relative 'msp'

def update_item items,h
  now = Time.now
  items.delete_if{|k,v| now - v[:ts] > 60}
  items[h[:icao]] ||= {hdr:0xffff, lat:0, lon:0, alt:0, icao:0, ttl:10,
                       tslc:255, ts:0, callsign:"", typ:0, posval:false}
  items[h[:icao]].update(h)
  items.sort_by {|_,v| -v[:ts].to_f}.to_h
end

def process_file(s, fnam, once)
  items={}
  lts = nil
  nl = 0
  File.open(fnam) do |fh|
    fh.each do |l|
      l.chomp!
      a = l.split(',')
      ts  = Time.parse([a[8],a[9]].join(' '))
      if lts
        p = l.split(',')
        h={}
        h[:icao] = p[4].to_i(16)
        if !p[10].nil? && !p[10].empty?
          h[:callsign] = p[10]
        end
        h[:ttl]  = 10
        h[:typ] = 0
        h[:tslc] = 1
        h[:ts] = Time.now
        if p[1] == "2" || p[1] == "3"
          lat = p[14].to_f
          lon = p[15].to_f
          hdr = p[13].to_i
          alt = p[11].to_f * 0.3048
 #           if hdr == 0
 #             if items[h[:icao]]
 #               xlat = items[h[:icao]][:lat]
 #               xlon = items[h[:icao]][:lon]
 #               hdr, d = Poscalc.csedist xlat,xlon,lat,lon
 #             end
 #           end
          h[:lat] = (lat*1e7).to_i
          h[:lon] = (lon*1e7).to_i
          h[:alt] = (alt*100).to_i
          h[:posval] = true
        elsif p[1] == "4"
          hdr = p[13].to_i
          h[:hdr] = hdr.to_i
        end
        items = update_item items, h

        if ts.sec != lts.sec
          if items.nil?
            items = {}
          else
            if items.length > 0
              vals = []
              j = 0
              items.values.each do |v|
                if j < 10 && v[:posval]
                  vals << v
                  j += 1
                  STDERR.puts v.inspect
                end
              end
              STDERR.puts
              MSP.adsb s, vals
            end
          end
        end
      end
      sleep ts - lts if lts and ts-lts > 0
      lts = ts
    end
  end
end


dev=nil
once=nil
rest = nil
ARGV.options do |opt|
  opt.banner = "Usage: sbs-player.rb [options] file"
  opt.on('-d', '--device DEV') {|o| dev=o}
  opt.on('-1', '--once') {once=true}
  opt.on('-?', "--help", "Show this message") {puts opt; exit}
  begin
    rest = opt.parse!
  rescue
    puts opt ; exit
  end
end

abort "No device" if dev.nil?

if dev.start_with? "udp://"
  u = URI.parse dev
  s = UDPSocket.new
  s.connect(u.host, u.port)
elsif dev == "/dev/null"
  s = File.open dev,"w"
else
  s = UART.open dev, 115200, '8N1'
end

process_file(s, rest[0], once)
