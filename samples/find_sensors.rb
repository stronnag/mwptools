#!/usr/bin/ruby
require 'find'

SENSORS=[:gyro, :acc, :baro, :mag, :optical_flow, :rangefinder]

def find_sensors fn
  s={}
  File.open fn do |fh|
    fh.each do |l|
      next unless l.match(/^\s*#define /)
      SENSORS.each do |ss|
	sn = ss.to_s.upcase
	if m = l.match(/USE_#{sn}_(\S+)/)
	  next if m[1].match(/DATA_READY/)
	  s[ss] ||= []
	  s[ss] << m[1]
	end
      end
    end
  end
  s
end

Dir.chdir(ARGV[0])


puts "| Target | Gyro | Acc  | Baro | Mag  | Optical Flow | Rangefinder | Target |"
puts "| ------ | ---- | ---- | ---- | ---- | ------------ | ----------- | ------ |"

Find.find('.').select { |f| f =~ /target\.h$/ }.each do |fn|
  target=File.dirname(fn).gsub('./','')
  devs = find_sensors(fn)
  cols = [target]
  mks = Dir.glob "#{target}/*.mk"
  multiple=(mks.size > 1)
  SENSORS.each do |ss|
    d = (devs[ss]||[])
    ds=d.sort.uniq
    multiple = true if d.size != ds.size
    cols << ds.join(' ')
  end
  if multiple
    cols[0] = "#{cols[0]} \\*"
  end
  cols << cols[0]
  str = cols.join(" | ")
  puts "| #{str} |"
end
puts
