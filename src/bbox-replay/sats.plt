# Generate SVG file from inav/bbox sat comaprison
# gnuplot -e 'filename="foo.txt"' sats.plt # => foo.txt.svg

set bmargin 8
set key top right
set key box
set grid

set term png font "/usr/share/fonts/truetype/freefont/FreeSans.ttf" 10

set xlabel "Time"

#set term X11 enhanced font "arial,15"
set title "Sat Coverage"
set ylabel "Sats/HDOP"
show label
set yrange [ 0 : 20 ]
set xrange [ 0 : ]
set datafile separator "\t"
set ytics 0,1,20

set terminal svg enhanced background rgb 'white' font "Droid Sans,9" rounded
set output filename.'.svg'

plot filename using 1:2 t "Sats" w lines lt -1 lw 2  lc rgb "red", '' using 1:3  t "Hdop" w lines lt -1 lw 2  lc rgb "blue"
