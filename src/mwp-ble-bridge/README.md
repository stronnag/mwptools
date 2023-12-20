# mwp_ble_bridge

## Overview

Standalone bridge for BLE serial, allowing the BLE device to be used with applications that are not BLE enabled.

The application connects to a specified BLE device and establishes a GATT connection. It then advertises a pseudo-terminal name that can be used with applications expecting a serial device node.

Alternately, TCP or UDP can be used in place of a pseudo-terminal. TCP will enable connectivity to the INAV configurator.

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

Note that when the application using the pseudo-terminal terminates, the  pseudo-terminal will be closed, which will cause `mwp-ble-bridge` to terminate as well, unless `--keep-alive` was given. TCP/IP based bridges are persistent.

## Environment

If the environment variable `MWP_BLE` is set, it will be used if BT device address is not supplied.

``` shell
# can be a well known environment source (/etc/environment, ~/.config/environment.d/)
$ export MWP_BLE=60:55:F9:A5:7B:16
# ...
$ mwp-ble-bridge
60:55:F9:A5:7B:16 <=> pseudo-terminal:  /dev/pts/7
### and (TCP)
$ mwp-ble-bridge -t
BLE chipset SpeedyBee Type 2, mtu 517
listening on tcp://localhost:40623
```

A device address given on the command line overrides `$MWP_BLE`. You may also give a device name (alias), with or without a `bt://` prefix.

``` shell
$ mwp-ble-bridge -u -a BleTest01
BLE chipset CC2541, mtu 23 (may not end well)
listening on udp://localhost:38899

$ mwp-ble-bridge -a bt://BleTest01
BLE chipset CC2541, mtu 23 (may not end well)
BleTest01 <=> /dev/pts/5
^CDisconnect
```

## Usage

``` shell
$ mwp-ble-bridge  --help
Usage:
  mwp-ble-bridge [OPTION?]  - BLE serial bridge

Help Options:
  -h, --help                 Show help options
  --help-all                 Show all help options
  --help-gapplication        Show GApplication options

Application Options:
  -a, --address              BT address
  -s, --settle               BT settle time (ms)
  -p, --port                 IP port
  -k, --keep-alive           keep alive
  -t, --tcp                  TCP server (vice pseudo-terminal)
  -u, --udp                  UDP server (vice pseudo-terminal)
  -V, --verbose              be verbose
  -v, --version              show version

 requires a BT address or $MWP_BLE to be set
```

Note that if an IP port is not specified, a random port will be assigned and shown.

## Installation

`mwp-ble-bridge` is installed by default when the mwptools project is installed. If desired, it is also possible just to build / install `mwp-ble-bridge`.

``` shell
cd src/mwp-ble-bridge
make
# This will install for the user in $HOME/.local/bin/
make install
# If instead you want it installed system wide
sudo make install prefix=/usr # install in /usr/bin
# or
sudo make install prefix=/usr/local # install in /usr/local/bin
```

# Dependencies

* Gcc or clang
* Vala
* Make
