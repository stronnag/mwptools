#!/usr/bin/ruby

require 'xmlsimple'
x=File.open(ARGV[0]||STDIN.fileno) {|f| f.read}
m=XmlSimple.xml_in(x,{'ForceArray' => false, 'KeepRoot' => false,
                     'KeyToSymbol' => true, 'AttrToSymbol' => true })

gs = {}

m[:schema][:key].each do |k|
  gs[k[:name]] = {summary: k[:summary],  description: k[:description], default: k[:default] }
end

puts '### List of mwp settings'
puts ''
puts '| Name | Summary | Description | Default |'
puts '| ---- | ------- | ----------- | ------ |'

gs.sort.each do |k,v|
  s = v[:summary]
  d = v[:description]
  begin
    d.gsub!("\n", " ")
    d.gsub!(/\s+/, ' ')
    d.strip!
  rescue
    STDERR.puts k,d.inspect
  end
  begin
    s.gsub!("\n", " ")
    s.gsub!(/\s+/, ' ')
    s.strip!
  rescue
    STDERR.puts k,s.inspect
  end
  puts "| #{[k,s, d, v[:default]].join(' | ')} |"
end
