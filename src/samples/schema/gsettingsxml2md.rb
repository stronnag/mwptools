#!/usr/bin/ruby

require 'xmlsimple'
x=File.open(ARGV[0]||STDIN.fileno) {|f| f.read}
m=XmlSimple.xml_in(x,{'ForceArray' => false, 'KeepRoot' => false,
                     'KeyToSymbol' => true, 'AttrToSymbol' => true })

gs = {}

m[:schema][:key].each do |k|
  gs[k[:name]] = {summary: k[:summary],  description: k[:description],
                  default: k[:default], ktype: k[:type]}
end

File.open("mwpsettings.md", "w") do |f0|
  STDERR.puts "Writing settings markdown to \"mwpsettings.md\""
  File.open("mwp.ini", "w") do |f1|
    STDERR.puts "Writing settings .ini to \"mwp.ini\""

    f0.puts '### List of mwp settings'
    f0.puts ''
    f0.puts '| Name | Summary | Description | Default |'
    f0.puts '| ---- | ------- | ----------- | ------ |'

    f1.puts "[mwp]"
    gs.sort.each do |k,v|
      s = v[:summary]
      d = v[:description]
      begin
        d.gsub!("\n", " ")
        d.gsub!(/\s+/, ' ')
        d.strip!
      rescue
        STDERR.puts "Desc #{k} #{d.inspect}"
      end
      begin
        s.gsub!("\n", " ")
        s.gsub!(/\s+/, ' ')
        s.strip!
      rescue
        STDERR.puts "Summary: #{k} #{s.inspect}"
      end
      f0.puts "| #{[k,s, d, v[:default]].join(' | ')} |"
      df = v[:default]
      df.gsub!('"', "'")
      f1.puts "#{k}=#{df}"
    end
  end
end
