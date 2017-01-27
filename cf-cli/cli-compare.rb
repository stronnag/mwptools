#!/usr/bin/ruby

# compare two CLI files and show the differences
# sorted / processed files are saved with __ prefix, so they can be
# graphically compared with meld or a similar tool

def process fn
  a=IO.readlines(fn)
  a.delete_if{|x| x.match(/^#|^$/)}
  a.sort!
  unless fn.match(/^__/)
    File.open("__#{fn}",'w') {|f| a.each {|l| f.puts l} }
  end
  a
end

diffs={}

a=process ARGV[0]
b=process ARGV[1]

res=a-b
res.each do |r|
  # removed / known renamed in 1.6
  next if r.match(/servo_lowpass_enable|acc_soft_lpf_hz|mmix/)
  if m=r.match(/^set (\S+) =/)
    diffs[m[1]]=1
  else
    a0=r.split(' ')[0]
    diffs[a0] = 1
  end
end
diffs.each {|k,v| puts k }
