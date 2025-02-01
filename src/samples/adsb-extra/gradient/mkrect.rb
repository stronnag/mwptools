#!/usr/bin/ruby

vert = !ENV["VERTICAL"].nil?

tw=125
th=5

if vert
  tw=5
  th=125
end


puts %Q|<svg width="#{tw}" height="#{th}" viewBox="0 0 #{tw} #{th}" version="1.1" id="svg1"
   xmlns="http://www.w3.org/2000/svg" xmlns:svg="http://www.w3.org/2000/svg">|
puts %Q|  <g id="alts">|
lx=0
ly = 0
if vert
  ly=120
end

ARGF.each do |l|
  l.chomp!
  if m=l.match(/alt\s+(\d+), id\s+(\d+), fill (\S+)/)
    puts "<rect"
    puts %Q|style="opacity:1;fill:#{m[3]};stroke:#{m[3]};stroke-width:0;stroke-dasharray:none"|
    puts %Q|id="alt_#{m[1]}" width="5" height="5" x="#{lx}" y="#{ly}" />|
    if vert
      ly -= 5
    else
      lx += 5
    end
  end
end
puts %Q| </g>
</svg>|
