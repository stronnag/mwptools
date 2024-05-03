#!/bin/bash

NUM=${1:-1}
DEN=${2:-1}

for F in *svg ; do
  R=$(identify -format "%w %h\n" $F)
  W=$(echo $R | cut -d ' ' -f 1)
  H=$(echo $R | cut -d ' ' -f 2)
  W1=$(($W*$NUM/$DEN))
  H1=$(($H*$NUM/$DEN))
  echo $F $W $H $W1 $H1
  mv $F _$F
  rsvg-convert -w $W1 -h $H1 -a -f svg -o $F _$F
done
