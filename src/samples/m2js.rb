#!/usr/bin/ruby

require 'xmlsimple'
require 'json'

x=File.open(ARGV[0]||STDIN.fileno) {|f| f.read}
m=XmlSimple.xml_in(x,{'ForceArray' => false, 'KeepRoot' => false,
		     'KeyToSymbol' => true, 'AttrToSymbol' => true })

if m.key?(:mwp)
     m[:meta] = m.delete(:mwp) if m.key?(:mwp)
     m[:meta][:generator] = 'mwp'
end
m.delete(:version)
m[:mission] = m.delete(:missionitem) if m.key?(:missionitem)
m[:mission].each do |i|
  i[:p1] = i.delete(:parameter1) if i.key?(:parameter1)
  i[:p2] = i.delete(:parameter2) if i.key?(:parameter2)
  i[:p3] = i.delete(:parameter3) if i.key?(:parameter3)
  i[:no] = i[:no].to_i
  i[:p1] = i[:p1].to_i
  i[:p2] = i[:p2].to_i
  i[:p3] = i[:p3].to_i
  i[:alt] = i[:alt].to_i
  i[:lat] = i[:lat].to_f
  i[:lon] = i[:lon].to_f
end

if m.key?(:meta)
  m[:meta][:zoom] = m[:meta][:zoom].to_i
  m[:meta][:cy] = m[:meta][:cy].to_f
  m[:meta][:cx] = m[:meta][:cx].to_f
  m[:meta][:details][:distance][:value] = m[:meta][:details][:distance][:value].to_i
  m[:meta][:details][:'nav-speed'][:value] = m[:meta][:details][:'nav-speed'][:value].to_f
  m[:meta][:details][:'fly-time'][:value] = m[:meta][:details][:'fly-time'][:value].to_i
  m[:meta][:details][:'loiter-time'][:value] = m[:meta][:details][:'loiter-time'][:value].to_i
end

if ARGV[1]
  puts JSON.pretty_generate(m)
else
  puts JSON.generate(m)
end
