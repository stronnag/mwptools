#!/usr/bin/ruby

# MIT licence

require 'nokogiri'

ARGV.each do |fn|
  doc=nil
  fix=false
  doc = Nokogiri.XML(File.open(fn))
  doc.xpath('//MISSIONITEM[@action="RTH"]').each do |l|
    if l['parameter1'] == "0"
      fix=true
      l['parameter1']=1
    end
  end
  if fix
    STDERR.puts "Set land on #{fn}"
    File.open(fn,'w') {|f| f.puts doc}
  end
end
