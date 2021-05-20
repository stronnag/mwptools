#!/bin/sh

# Simple bridge for testing mwp TCP mode with mspsim (which is UDP only)
# mspsim -u 10000
# ./socat-bridge.sh
# mwp -s tcp://localhost:20000

TCPPORT=${1:-20000}
UDPPORT=${1:-10000}

# replace ip6 with ip4 for legacy networking
socat TCP-LISTEN:$TCPPORT,pf=ip6,reuseaddr,fork UDP:localhost:$UDPPORT,reuseaddr
