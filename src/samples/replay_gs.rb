#!/usr/bin/ruby

ARGF.each do |l|
  l.chomp!
  l.gsub!('uint32','')
  l.gsub!('@as','')
  l.gsub!(" [",' "[')
  l.gsub!(/\]$/,']"')
  puts "gsettings set #{l}"
end
