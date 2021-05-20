# Generate SVG file from inav/bbox mag comaprison
# gnuplot -e 'filename="mission.csv"' mag.plt # => mission.csv.svg

set bmargin 8
set key top right
set key box
set grid

set term png font "/usr/share/fonts/truetype/freefont/FreeSans.ttf" 10

set xlabel "Time"

#set term X11 enhanced font "arial,15"
set title "Mag v GPS"
set ylabel "deg"
show label
set yrange [ 0 : 360 ]
set xrange [ 0 : ]
set datafile separator ","

set terminal svg enhanced background rgb 'white' font "Droid Sans,9" rounded
set output filename.'.svg'

plot filename using 1:($8 < 0?1/0:$8) t "gps" w lines lt -1 lw 2  lc rgb "green", '' using 1:($7 < 0?1/0:$7)  t "mag" w lines lt -1 lw 2  lc rgb "red"
