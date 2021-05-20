mwp-uploader
===========

Simple standalone uploader for iNav / MultiWii compatible mission files.

## Overview

`mwp-uploader` performs the upload (optionally save to eeprom) and validation of XML (mwp, ezgui, Mission Planner for iNav) and JSON (mwp) mission files to an iNav or MultiWii flight controller.

````
$ ./mwp-uploader --help
Usage:
  mwp-uploader [OPTION?]  - Mission UPloader

Help Options:
  -h, --help        Show help options

Application Options:
  -b, --baud        baud rate
  -d, --device      device
  -m, --mission     mission file
  -s, --save=false  save to eeprom
````

By default, output is logger to STDERR and a result message written to STDOUT. The exit status is set to 0 if the upload was successful and 1 if not. If STDERR is redirected, then the output is redirected (appended) to the stanndard mwp log file, `mwp_stderr_YYYY-MM-DD.txt`.

This may be used in scripts, for example:

````
RES=$(./mwp-uploader -m ~/Projects/quads/missions/jtest.mission  -s 2> /dev/null)
if [ $? = 0 ] ; then
  echo $RES
else
  echo "Upload failed, please see log file mwp_stderr_$(date +%F).log"
fi
````

If no device is given, `mwp-uploader` will try to auto-detect the FC.
