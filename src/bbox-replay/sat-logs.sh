#!/bin/bash

# Find all BB Logs from a given root and graph the sat coverage
# Assumes mwptools/bbox-replay/inav_sats.rb on $PATH
# Fix up the location of sats.plt to suit ...
# ./sat-logs.sh /t/inav/ # all my inav logs ... may take some time

BASE=${1:-.}
PLT=~/Projects/mwptools/bbox-replay/sats.plt

for F in $(find $BASE -iname LOG0\*.TXT -size +1M)
do
  FN=$(basename $F)
  for n in {1..10}
  do
    DFILE=${FN%%.TXT}_$n.txt
    if inav_sats.rb -i $n $F > /tmp/$DFILE
    then
      echo $F $n
      gnuplot -e "filename=\"/tmp/$DFILE\"" $PLT
      convert /tmp/$DFILE.svg /tmp/$DFILE.png
      rm -f /tmp/$DFILE
    else
      rm -f /tmp/$DFILE
      break
    fi
  done
done
