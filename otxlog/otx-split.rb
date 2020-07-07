#!/usr/bin/ruby

require 'csv'
require 'time'

infile=nil
ssecs=30

if ARGV.size > 0
  infile = ARGV[0]
end
if ARGV.size > 1
  ssecs = ARGV[1].to_i
end

abort "no file" if infile.nil?

splits=[]
csv = CSV.open(ARGV[0], :col_sep => ",", :headers => :true)
lt=nil
i = 0
nhdr = false
hdrs=nil

csv.each do |c|
  if  nhdr == false
    hdrs = c
    nhdr = true
  else
    ts = c[0]+' '+c[1]
    t = Time.parse(ts)
    if lt
      tdiff = t - lt
      if tdiff > 30
        splits << i
      end
    end
    lt = t
  end
  i += 1
end

if splits.size > 0
  splits << 99999999
  ext = File.extname(ARGV[0])
  bf = File.basename(ARGV[0],ext)
  File.open(ARGV[0]) do |fh|
    header = fh.readline
    i = 1
    ln = 1
    splits.each do |n|
      fn = File.join("/tmp","#{bf}-#{ln}#{ext}")
      puts "Creating #{fn}"
      ln += 1
      File.open(fn, "w") do |fo|
        fo.puts header
        fh.each do |l|
          if i == n
            break
          end
          fo.puts l
          i += 1
        end
      end
    end
  end
else
  puts "Only one file"
end
