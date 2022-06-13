#!/usr/bin/ruby

# Extract altitude etc for analysis
# MIT licence
# Dependencies: ruby, gnuplot, blackbox_decode

require 'csv'
require 'optparse'

idx = 1
every = 0
outf = nil
graph = false
amsl = false
delta = 0.1

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX'){|o|idx=o}
  opt.on('-d', '--delta=SECS', Float, "Down sample interval (default 0.1s)") {|o| delta = o}
  opt.on('-o','--output=FILE'){|o|outf=o}
  opt.on('-p','--plot'){graph=true}
  opt.on('-a','--amsl'){amsl=true}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

bbox = (ARGV[0]|| abort('no BBOX log'))
cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --merge-gps"
cmd << " --unit-frame-time s"
cmd << " --stdout"
cmd << " " << bbox

st = nil
fh = nil
rm = false

svgf = nil

if outf.nil? && graph.nil?
  outf =  STDOUT.fileno
elsif outf.nil?
  ext = File.extname(bbox)
  if ext.empty?
    outf = "#{bbox}-alt.csv"
    svgf = "#{bbox}-alt##{idx}.svg"
  else
    outf = bbox.gsub("#{ext}", '-alt.csv')
    svgf = bbox.gsub("#{ext}", "-alt##{idx}.svg")
  end
  rm = true
end

n = 0
IO.popen(cmd,'r') do |p|
  File.open(outf,"w") do |fh|
    csv = CSV.new(p, :col_sep => ",",
		  :headers => :true,
		  :header_converters =>
		  ->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		  :return_headers => true)
    hdrs = nil
    gpsz = nil
    lts = 0
    id=0
    ahdrs = %w/Time Baro GPS_agl Est_Alt/
    if amsl
      ahdrs << 'GPS_amsl'
    end

    csv.each do |c|
      id += 1
      if hdrs.nil?
        hdrs = csv
        fh.puts ahdrs.join(',')
      else
        n += 1
        next if c[:gps_numsat].to_i < 6
        ts = c[:time_s].to_f
        st = ts if st.nil?
        xts  = ts - st
        if xts - lts > delta
          baro_alt = c[:baroalt_cm].to_f / 100
          gpsalt = c[:gps_altitude].to_f
          estalt = c[:navpos2].to_f / 100
          if gpsz.nil?
	    gpsz = gpsalt
          end
          gpsd = gpsalt - gpsz
          arry = [xts,baro_alt,gpsd,estalt]
          if amsl
            arry << gpsalt
          end
          if xts > lts
            fh.puts arry.join(',')
          else
            STDERR.puts "Backwards time at line #{id} #{ts} #{xts} #{lts}"
          end
          lts = xts
        end
      end
    end
  end
end

if graph && n > 0
  fn = File.basename bbox
  pltfile = DATA.read % {:bbox => "#{fn} / ##{idx}", :svgfile => svgf}
  if amsl
    pltfile.chomp!
    pltfile << ', filename using 1:5 t "GPS AMSL" w lines lt -1 lw 2  lc rgb "green"'
  end
  File.open(".inav_gps_alt.plt","w") {|plt| plt.puts pltfile}
  system "gnuplot -e 'filename=\"#{outf}\"' .inav_gps_alt.plt"
  STDERR.puts "Graph in #{svgf}"
  File.unlink ".inav_gps_alt.plt"
end

File.unlink outf if rm

__END__
set bmargin 8
set key top right
set key box
set grid
set termopt enhanced
set termopt font "sans,8"
set xlabel "Time(s)"
set title "Altitude Comparison %{bbox}" noenhanced
set ylabel "Elev (m)"
show label
set xrange [ 0 : ]
#set yrange [ 0 : ]
set datafile separator ","
set terminal svg background rgb 'white' font "Droid Sans,9" rounded
set output "%{svgfile}"
plot filename using 1:2 t "Baro" w lines lt -1 lw 3  lc rgb "blue", filename using 1:3 t "GPS AGL" w lines lt -1 lw 2  lc rgb "red", filename using 1:4 t "Est Alt" w lines lt -1 lw 2  lc rgb "gold"
