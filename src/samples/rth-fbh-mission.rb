#!/usr/bin/ruby
require 'xmlsimple'
require 'optparse'
require 'tempfile'

outfile=nil
act = nil

ARGV.options do |opt|
  opt.on('-a','--act') {|o| act=true}
  opt.on('-o','--output=FILE') {|o| outfile=o}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

doc=IO.read(ARGV[0] || STDIN)
doc.downcase!
m=XmlSimple.xml_in(doc, {'ForceArray' => false, 'KeepRoot' => true})
mx = nil
if m['mission']['mwp']
  mx = m['mission']['mwp']
elsif  m['mission']['meta']
  mx = m['mission']['meta']
end

m['mission']['missionitem'].each_with_index do |mi,j|
  mi['action'].upcase!
  if mi['flag'].to_i == 72
    mi['lat'] = 0.0
    mi['lon'] = 0.0
    if act
      mi['flag'] = 0
      mi['action'] = "RTH"
    end
  end
end
xml = XmlSimple.xml_out(m, { 'KeepRoot' => true })
if outfile.nil?
  puts xml
else
  IO.write(outfile, xml)
end
