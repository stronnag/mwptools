#!/usr/bin/ruby

# MIT licence

require 'fileutils'
require 'sequel'
require 'optparse'

odbfile=nil
dbfile=nil
dburi=nil
nlat=nil
nlon=nil
verbose=false
rest=nil
idx = 1

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-d','--dbfile DBFN', "Extant DB"){|o| odbfile=o}
  opt.on('--lat LAT', "new base lat", Float){|o| nlat=o}
  opt.on('--lon LON', "new base lon", Float){|o| nlon=o}
  opt.on("-i", '--index IDX', "log index", Integer){|o| idx=o}
  opt.on('-v','--verbose'){|o| verbose=true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

fn = ARGV[0]
abort "Need a new db file" if fn.nil?
dburi = "sqlite://#{fn}"

STDERR.puts "#{fn} => #{dburi}" if verbose

FileUtils.cp(odbfile, fn)

db = Sequel.connect dburi

res = db[:logs].where(:id => idx).get([:hlat,:hlon])
hlat=res[0]
hlon=res[1]
ladif = nlat-hlat
lodif = nlon-hlon
puts "lat diff #{ladif}, lon diff #{lodif}" if verbose
n=db[:logs].where(:id => idx).update(:hlat => nlat, :hlon => nlon,
                                   :lat=>Sequel.expr(:lat)+ladif,
                                   :lon=>Sequel.expr(:lon)+lodif)

puts "Updated #{n} rows" if verbose
db.disconnect
