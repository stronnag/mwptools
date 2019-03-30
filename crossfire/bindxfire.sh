#!/bin/bash

CROSSFIREMAC="00:04:3E:48:45:4F"
RFCOMM=`which rfcomm`
HCIDEV="hci0"
CHANNEL="1"

sudo ${RFCOMM} bind ${HCIDEV} ${CROSSFIREMAC} ${CHANNEL}

