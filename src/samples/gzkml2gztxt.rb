#!/usr/bin/ruby
require 'xmlsimple'
require 'optparse'

cli = true
ARGV.options do |opt|
  opt.on('-p','--pretty'){cli=false}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

doc=IO.read(ARGV[0] || STDIN)
doc.downcase!
m=XmlSimple.xml_in(doc, {'ForceArray' => false, 'KeepRoot' => false})
if m['folder']
  if m['folder']['folder']
    x = true
    m['folder']['folder'].each do |f|
      e = f['extendeddata']
      if e
        if x
          puts "# geozone"
          x = false
        else
          puts
        end
        puts "geozone #{e['id']} #{e['shape']} #{e['type']} #{e['minalt']} #{e['maxalt']} #{e['action']}"
        if e['shape'] == "0"
          puts "geozone vertex #{e['id']} 0 #{e['centre-lat']} #{e['centre-lon']}"
          puts "geozone vertex #{e['id']} 1 #{e['radius']} 0"
        else
         c = f['placemark']['polygon']['outerboundaryis']['linearring']['coordinates']
         cp = c.split(' ')
         # length -1 (as closed)
         0.upto(cp.length-2) do |i|
           cr = cp[i]
           lo,la,al = cr.split(',')
           la = (la.to_f*1e7+0.5).to_i
           lo = (lo.to_f*1e7+0.5).to_i
           puts "geozone vertex #{e['id']} #{i} #{la} #{lo}"
         end
        end
      end
    end
  end
end
