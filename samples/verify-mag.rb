#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'sequel'
require_relative 'poscalc'

id1 = ARGV[0].to_i
id2 = ARGV[1].to_i

lat0 = nil
lon0 = nil

dburi='sqlite://f.sqlite'
db = Sequel.connect dburi

reps=nil
if id1 != id2
  reps = db[:reports].where{(id > id1) & (id < id2)}.select(:id,:lat,:lon,:cse,:heading).order(:id)
else
  reps = db[:reports].where(:armed => 1).select(:id,:lat,:lon,:cse,:heading).order(:id)
end

puts %w/id calc cse head/.join("\t")
reps.each do |r|
  if lat0 and lon0
    c,d =  Poscalc.csedist lat0,lon0,r[:lat],r[:lon]
    str = "%4d\t%3d\t%3d\t%3d" % [r[:id],  c, r[:cse], r[:heading]]
    puts str
  end
  lat0 = r[:lat]
  lon0 = r[:lon]
end
