#!/bin/sh

########## Only needed for old libsoup, e.g. Ubuntu 14.04 or earlier ########
# add your port (from sources.json) and URI
qproxy #port #URI &
qpid=$!
mwp
kill $qpid
