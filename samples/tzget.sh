#!/bin/bash

# Using ZoneDetect https://github.com/BertoldVdb/ZoneDetect
# based on data from https://github.com/evansiroky/timezone-boundary-builder
# the latter has links to other implementations
#
# ZoneDetect databses:
#  timezone16.bin has a longitude resolution of 0.0055 degrees (~0.5km).
#  timezone21.bin has a longitude resolution of 0.00017 degrees (~20m).
#
# Example installation
# sudo cp library/libzonedetect.so /usr/local/lib
# sudo cp -a  database /usr/local/share/zonedectect
# sudo cp zdemo /usr/local/bin/zone-detect
# sudo ldconfig
#

DATABASE=/usr/local/share/zonedectect/timezone21.bin
ZONE=
while read K V
do
  case $K in
    TimezoneIdPrefix:) ZONE=$V ;;
    TimezoneId:) ZONE=${ZONE}${V} ;;
  esac
done < <(zone-detect $DATABASE $1 $2)
echo $ZONE
