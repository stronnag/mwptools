#!/usr/bin/ruby
require 'nokogiri'

# Replicate a set of way points
# replicate_wps.rb wps.mission first last [iterations]
# so:
# with a source.mission of WP1, WP2, WP3, WP4, RTH
# replicate_wps.rb source.mission 2 3 3
# would give
#
# wp1, wp2, wp3 wp2, wp3 wp2, wp3 wp2, wp3 wp4 rth
# but renumbered correctly
#
# may be useful for repeating mission
#
# MIT licence

fn=ARGV[0]
if ARGV.empty? || !File.exists?(fn)
  STDERR.puts "Usage: replicate_wps.rb mission_file first last [iterations]"
  exit
end

se=ARGV[1].to_i
ee=ARGV[2].to_i
rep=(ARGV[3] || 1).to_i


doc = Nokogiri::XML(open(fn))
items=[]
inc = nil
ninc = 0
doc.xpath(%Q(//MISSION/MISSIONITEM|//mission/missionitem)).each do |x0|
  if x0['no'].to_i >= se and x0['no'].to_i <= ee
    items << x0
  end
  if inc
    x0['no'] = x0['no'].to_i + ninc
  end
  if x0['no'].to_i == ee
    inc = true
    xn = x0
    basen = xn['no'].to_i
    1.upto(rep) do |m|
      items.each do |x|
        x2 = Nokogiri::XML::Node.new "missionitem",doc
        ninc += 1
	orig = x['no']
	x.each {|k,v| x2[k] = v}
	x2['no'] = basen + ninc
	x2['orig_wp'] = orig
        xn.after(x2)
        xn = x2
      end
    end
  end
end
puts doc.to_xml({:indent => 2})
