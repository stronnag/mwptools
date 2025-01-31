#!/bin/bash

FC=${1:-1}
if [[ $# -gt 1 ]] ; then
  IC=${2:-1}
  FC=$(dc -e "2 k $FC $IC / p")
fi
for F in *.svg ; do
  R=$(identify -format "%w %h\n" $F)
  W=$(echo $R | cut -d ' ' -f 1)
  H=$(echo $R | cut -d ' ' -f 2)
  W1=$(dc -e "2 k $W  $FC * p")
  H1=$(dc -e "2 k $H  $FC * p")
  echo $F $W $H $W1 $H1
  mv $F _$F
  rsvg-convert -w $W1 -h $H1 -a -f svg -o $F _$F
done
