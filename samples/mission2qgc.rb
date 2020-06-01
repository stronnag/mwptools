#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'nokogiri'

class QGCBuilder

  XLATE = {
    'WAYPOINT' => 16, # p1 is hold time (=> poshold_time)
    'POSHOLD_UNLIM' =>  17,
    'POSHOLD_TIME' => 16,  # (16+p1=time)
    'RTH' => 20,
    'SET_POI' => 80, #tbd
    'JUMP' => 177, # (p1=target wp, p2=repeats)
    'SET_HEAD' => 115, # p1 = angle
    'LAND' => 21
  }

  def initialize debug=nil
    @debug=debug
  end

  def pts_from_file inf
    pos = []
    cx = cy = nil
    doc = Nokogiri::XML(open(inf))
    xy = doc.xpath('//mwp').first
    if xy
      cx = (xy['cx']||0.0).to_f
      cy = (xy['cy']||0.0).to_f
    end
    doc.xpath('//missionitem').each do |t|
      action=t['action']
      no = t['no'].to_i
      lat = t['lat'].to_f
      lon = t['lon'].to_f
      alt = t['alt'].to_i
      p1 = t['parameter1'].to_i
      p2 = t['parameter2'].to_i
      p3 = t['parameter3'].to_i
      pos << {:no => no, :lat => lat, :lon => lon, :alt => alt, :act => action,
	:p1 => p1, :p2 => p2, :p3 => p3}
    end
    if cx.nil?
      cx = cy = 0
      np = 0
      pos.each do |p|
        if p[:lon] !=0 && p[:lat] != 0
          cx += p[:lon]
          cy += p[:lat]
          np += 1
        end
      end
      cx /= np
      cy /= np
    end
    [pos,[cx,cy]]
  end

  def build arrys, outf
    File.open(outf,'w') do |f|
      f.puts "QGC WPL 110"
      arry = arrys[0]
      hp = arrys[1]
      f.puts [0,0,0,16,0,5,0,0,hp[1],hp[0],0,1].join("\t")
      arry.each do |m|
	qgc=[]
	qgc << m[:no] << 0 << 0
	qgc << XLATE[m[:act]]
	case  m[:act]
	when 'WAYPOINT','RTH','LAND','POSHOLD_UNLIM','SET_POI'
	  qgc << 0 << 0 << 0 << 0
	  qgc << m[:lat] << m[:lon] << m[:alt] << 1
	when 'POSHOLD_TIME'
	  qgc << m[:p1] << 0 << 0 << 0
	  qgc << m[:lat] << m[:lon] << m[:alt] << 1
	when 'JUMP'
	  qgc << m[:p1] << m[:p2] << 0 << 0 ### check mapping
	  qgc << m[:lat] << m[:lon] << m[:alt] << 1
	when 'SET_HEAD'
	  qgc << m[:p1] << 0 << 0 << 0 ### check
	  qgc << 0 << 0 << 0 << 1
	end
	f.puts qgc.join("\t")
      end
    end
  end
end

if __FILE__ == $0
  q = QGCBuilder.new
  arrys = q.pts_from_file ARGV[0]
  q.build arrys, (ARGV[1]||STDOUT.fileno)
end
