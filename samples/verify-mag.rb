#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# MIT licence

require 'sequel'
require 'optparse'
require_relative 'poscalc'

mid=1
id1 = id2 = nil
dburi=nil

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [dburi]"
  opt.on('-1','--id1=ID1',Integer,'first report id'){|o|id1=o}
  opt.on('-2','--id2=ID2',Integer,'last report id'){|o|id2=o}
  opt.on('-m','--mission=MID',Integer,'Mission index'){|o|mid=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

lat0 = nil
lon0 = nil

dburi = (ARGV[0] || 'sqlite://f.sqlite')
STDERR.puts "using #{dburi}"
db = Sequel.connect dburi

reps=nil
if id1 != id2
  reps = db[:reports].where(:mid => mid).where{(id > id1) & (id < id2)}.select(:id,:lat,:lon,:cse,:heading).order(:id)
else
  reps = db[:reports].where(:mid => mid).where(:armed => 1).select(:id,:lat,:lon,:cse,:heading).order(:id)
end

puts %w/id calc cse head/.join("\t")
reps.each do |r|
  if lat0 and lon0 and r[:cse] and r[:heading]
    c,d =  Poscalc.csedist lat0,lon0,r[:lat],r[:lon]
    str = "%4d\t%3d\t%3d\t%3d" % [r[:id],  c, r[:cse], r[:heading]]
    puts str
  end
  lat0 = r[:lat]
  lon0 = r[:lon]
end
