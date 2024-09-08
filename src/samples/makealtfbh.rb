#!/usr/bin/ruby
require 'xmlsimple'
require 'optparse'

cli = true
ARGV.options do |opt|
  opt.on('-p','--pretty'){cli=false}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

doc=IO.read(ARGV[0] || STDIN)
doc.downcase!
m=XmlSimple.xml_in(doc, {'ForceArray' => false, 'KeepRoot' => true})
m['mission']['missionitem'].each_with_index do |i,n|
  i['action'].upcase!
  if i['flag']
    flag = i['flag'].to_i
    if n.odd?
      if flag == 0
        i['flag'] = '72'
      end
    end
  end
end

puts XmlSimple.xml_out(m, { 'KeepRoot' => true })
