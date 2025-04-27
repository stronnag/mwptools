#!/usr/bin/ruby

# mwp --debug-flags 4
# 12:00:34.802658 :DBG: MSP send: MSP:ATTITUDE 0x6c/108
# 12:00:34.857158 :DBG: MSP recv: MSP:ATTITUDE 0x6c/108 0

stats = {}
lsend = nil
ltim = nil
ARGF.each do |l|
  if l.match(/:DBG: MSP/)
    m = l.match(/(..):(..):(\S+) :DBG: MSP (\S+): (\S+)/)
    et = (m[1].to_f*60+m[2].to_f)*60+m[3].to_f
    if m[4] == "send"
      lsend = m[5]
      ltim = et
    elsif m[4] == "recv" and m[5] == lsend
      tdif = et - ltim
      stats[m[5]] ||= {avg: 0, count: 0, min: tdif, max: tdif}
      if tdif < stats[m[5]][:min]
        stats[m[5]][:min] = tdif
      end
      if tdif > stats[m[5]][:max]
        stats[m[5]][:max] = tdif
      end
      n0 = stats[m[5]][:count]
      n1 = n0 + 1
      stats[m[5]][:avg] = (stats[m[5]][:avg]*n0 + tdif) / n1
      stats[m[5]][:count] = n1
    end
  end
end
#stats.each do |k,v|
#  flag = v[:max] > 0.9 ? " *" : ""
#  STDOUT.puts "%28.28s: avg=%.3f min=%.3f max=%.3f count=%d%s" % [ k, v[:avg], v[:min], v[:max]#, v[:count], flag]
#end

puts "| Message | Average(s) | Minimum(s) | Maximum(s) | Count | Flag |"
puts "| ------- | ---------- | ---------- | ---------- | ----- | ---- |"
stats.each do |k,v|
  flag = v[:max] > 0.9 ? "*" : ""
  puts "| " + [k, "%.3f" % v[:avg], "%.3f" % v[:min], "%.3f" % v[:max], v[:count], flag].join(" | ") + " |"
end
