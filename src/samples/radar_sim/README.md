# mwp-radar-sim

## Overview

`mwp-inav-radar-sim` is a simulator for the MSP based inav-radar protocol. It simulates 4 aircraft, flying from central location, staying withing a defined range, with specified speed and altitude. The values for heading, speed and altitude have random perturbations applied during the simulation and 'fly' within a specified range of defined start point.

`mwp-mavlink-traffic-sim` is a simulator for the  MAVLink TRAFFIC REPORT protocol. It behaves in a similar fashion.


## Building

Niether simulator is built by default, it is necessary to:

```
cd mwptools/src/samples/mwp-radar-sim
make
# or (install to $HOME/.local/bin)
make prefix=~/.local
```

Note:
* It is necessary to have installed to the mwptools project in order to access the required libraries
* The script assumes `$prefix` (default `/usr/local`) is the same as used to install mwptools.
* Otherwise, you can set INCDIR, LIBDIR and VAPIDIR environment variables to take into account the installed locations.

## Usage

```
$ mwp-inav-radar-sim --help
Usage:
  mwp-radar-sim [OPTION?]  - iNav radar simulation tool

Help Options:
  -h, --help                 Show help options

Application Options:
  -b, --baud=115200          baud rate
  -d, --device=name          device
  -c, --centre=lat,long      Centre position
  -r, --range=metres         Max range
  -s, --speed=metres/sec     Initial speed
  -a, --alt=metres           Initial altitude
  -2, --mspv2                Use MSPV2
  -m, --max-radar=4          number of radar slots
```
### Options

* **device** : The name of the input device; all mwp device options are available (serial, IP, BT, USB, wifi, sockets etc.) e.g.
 - `/dev/ttyUSB0`, `/dev/ttyACM0` (usb ttl adapters)
 - `/dev/rfcomm0`, `00:14:03:11:35:16` (BT, by device or address)
 - `udp://:3000`, `tcp://random-host:23` (IP sockets)

  On Linux, `/dev/ttyUSB0` and `/dev/ttyACM0` are automatically probed.

* **baud** : Where required, default is `115200`

* **centre** : The central location / start point. A delimited string of decimal latitude and longitude, delimiters are ' ' or ','. Locale aware, default is `"54.353974 -4.5236"`.

* **range** : The maximum range before the simulated aircraft turn around, default is 500m.

* **speed** : Initial speed, default 15 m/s.

* **alt** : Initial altitude, default is 50m.

* **mspv2** : Use MSPv2 protocol (default is v1)

* **max-radar** : Number of radar slots, default is 4.

## Sample usage

Start mwp:

```
$ mwp  --centre "54.353974 -4.5236"  -d udp://:3000 --no-poll -a [--relaxed-msp]
# or
$ mwp  --centre "54.353974 -4.5236"  --radar-device udp://:3000
```

For a local test, this uses UDP sockets.

For convenience, the `--centre` parameter matches the `mwp-radar-sim` default.

Then start the simulator:

```
$ mwp-inav-radar-sim -d udp://localhost:3000
```

Similarly:

``` vala
$ ./mwp-mavlink-traffic-sim --help
Usage:
  mwp-mavlink-traffic-sim [OPTION?]  - mavlink traffic report simulation tool

Help Options:
  -h, --help                Show help options

Application Options:
  -b, --baud=115200         baud rate
  -d, --device=name         device
  -c, --centre=lat,long     Centre position
  -m, --max-radar=256       number of radar slots
```
