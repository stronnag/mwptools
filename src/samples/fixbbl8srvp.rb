#!/usr/bin/env ruby

abort "Need input and outout files" if (ARGV.length != 2)

File.open(ARGV[1],'wb') do |fw|
  File.open(ARGV[0],'rb') do |fr|
    fr.each do |l|
      if l.match(/^H Field I name:/)
        puts "Patching"
        ll = l.sub('servo[15]','servo[15],servo[16],servo[17]')
        fw.puts(ll);
      elsif l.match(/^H Field I predictor:/)
        ll = l.sub('8,8,0,','8,8,8,8,0,')
        fw.puts(ll);
      else
        fw.puts(l);
      end
    end
  end
end
