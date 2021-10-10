#!/bin/bash

# The WSL is also the default gateway
# Assumes you're running `ser2udp` on the Windows side.
WSLIP=$(ip route show 0.0.0.0/0  | cut -d\  -f3)
exec mwp -d udp://${WSLIP}:17071 $@
