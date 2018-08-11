#!/usr/bin/ruby
require 'find'

SENSORS=[:gyro, :acc, :baro, :mag, :optical_flow, :rangefinder]

def find_sensors fn
  s={}
  File.open fn do |fh|
    fh.each do |l|
      next unless l.match(/^#define /)
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


puts "| Target | Gyro | Acc  | Baro | Mag  | Optical Flow | Rangefinder |"
puts "| ------ | ---- | ---- | ---- | ---- | ------------ | ----------- |"

Find.find('.').select { |f| f =~ /target\.h/ }.each do |fn|
  target=File.dirname(fn).gsub('./','')
  devs = find_sensors(fn)
  str = "| #{target} |"
  SENSORS.each do |ss|
    str << " " << (devs[ss]||[]).join(' ') << " |"
  end
  puts str
end
puts
