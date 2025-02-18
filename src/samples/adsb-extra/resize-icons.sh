#!/bin/bash

if ! type -t > /dev/null identify ; then
  echo "This script requires "identify" (typically from imagemagick)"
  exit 127
fi
if ! type -t > /dev/null rsvg-convert ; then
  echo "This script requires "rsvg-convert" (typically from librsvg)"
  exit 127
fi

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
echo "For ADSB symbols, you may have to (re)apply  'id=\"mwpfg\"' and 'id=\"mwpbg\"' attributes to the resized icons : see gradient/README.md"
echo "For other symbols, you may have to (re)apply 'mwp:xalign' or 'mwp:yalign' attributes to the resized icons"
