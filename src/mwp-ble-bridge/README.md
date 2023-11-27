# mwp_ble_bridge

## Overview

Standalone bridge for BLE serial, allowing the BLE device to be used with applications that are not BLE enabled.

The application connects to a specified BLE device and establishes a GATT connection. It then advertises a pseudo-terminal name that can be used with applications expecting a serial device node.

For example:

```
# Make the GATT connection
$ mwp-ble-bridge 60:55:F9:A5:7B:16
60:55:F9:A5:7B:16 <=> pseudo-terminal:  /dev/pts/7
```

Then the advertised pseudo-terminal (above, `/dev/pts/7`) can be used in otherwise non-BLE aware applications.

``` shell
$ impload -d /dev/pts/7 upload Terrain_follow.mission
2023/10/28 12:52:26 Using device [/dev/pts/7]
INAV v7.0.0 WINGFC (ad8e1a3c) API 2.5 "BENCHYMCTESTY"
Extant waypoints in FC: 0 of 120, valid 0
upload 76, save false
Waypoints: 76 of 120, valid 1
```

Note that when the application using the pseudo-terminal terminates, the  pseudo-terminal will be closed, which will cause `mwp-ble-bridge` to terminate as well.

## Environment

If the environment variable `MWP_BLE` is set, it will be used if BT device address is not supplied.

``` shell
# can be a well known environment source (/etc/environment, ~/.config/environment.d/)
$ export MWP_BLE=60:55:F9:A5:7B:16
# ...
$ mwp-ble-bridge
60:55:F9:A5:7B:16 <=> pseudo-terminal:  /dev/pts/7
```
A device address given on the command line overrides `$MWP_BLE`.
