#!/bin/sh

########## Only needed for old libsoup, e.g. Ubuntu 14.04 or earlier ########
# add your port (from sources.json) and URI
# but make sure you keep the ampersand at the end &&&&&
#                vvv
qproxy #port #URI &
qpid=$!
mwp
kill $qpid
