#!/usr/bin/ruby

require 'optparse'

vert = false
size=125
opacity=1.0
fcol="#ffffff"

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options]"
  opt.on('-c','--font-colour=VAL','fcol (rbg, default #ffffff)'){|o|fcol=o}
  opt.on('-o','--opacity=VAL',Float,'opacity (0-1)'){|o|opacity=o}
  opt.on('-s','--size=VAL',Integer,'dominant size'){|o|size=o}
  opt.on('-v','--vertical','orientation'){vert=true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

opacity = 1.0 if opacity > 1 || opacity < 0
offset = 40
incr = size / 25;
tw=size+offset+12
th=12
iw=incr
ih=5
if vert
  tw=5
  th=size
  ih=incr
  iw=5
  offset = 0
end

puts %Q|<svg width="#{tw}" height="#{th}" viewBox="0 0 #{tw} #{th}" version="1.1" id="svg1"
   xmlns="http://www.w3.org/2000/svg" xmlns:svg="http://www.w3.org/2000/svg">|
puts %Q|  <g id="alts">|
lx=0
ly = 0
if vert
  ly=size-incr
else
  puts %Q|<text
     id="texta"><tspan id="tspana" x="0" y="9.8"
       style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:6px;line-height:1;font-family:'Sans';fill:#{fcol}">Alitude (m)</tspan></text>|
end

ARGF.each do |l|
  l.chomp!
  if m=l.match(/alt\s+(\d+), id\s+(\d+), fill (\S+)/)
    id = m[2].to_i
    xp = lx+offset
    puts "<rect"
    puts %Q|style="opacity:#{opacity};fill:#{m[3]};stroke:#{m[3]};stroke-width:0;stroke-dasharray:none"|
    puts %Q|id="alt_#{m[1]}" width="#{iw}" height="#{ih}" x="#{xp}" y="#{ly}" />|
    if !vert
      if id == 0 || id == 2 || id == 6 || id == 12 || id == 18 || id == 24
        text=m[1]
        if id == 0
          text="-0"
          xp -= 2
        elsif id == 24
          text = "12000+"
        end
        puts %Q|
    <text
     id="text#{id}"><tspan id="tspan#{id}" x="#{xp}" y="10"
       style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:6px;line-height:1;font-family:'Sans'; fill:#{fcol}">#{text}</tspan></text>|
      end
    end
    if vert
      ly -= incr
    else
      lx += incr
    end
  end
end
puts %Q| </g>
</svg>|
