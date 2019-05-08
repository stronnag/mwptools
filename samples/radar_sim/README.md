# mwp-radar-sim

## Overview

`mwp-radar-sim` is a simulator for the MSP based inav-radar protocol. It simulates 4 aircraft, flying from central location, staying withing a defined range, with specified speed and altitude. The values for heading, speed and altitude have random perturbations applied during the simulation and 'fly' within a specified range of defined start point. 

## Building

`mwp-radar-sim` is not built by default, it is necessary to:

```
cd mwptools/samples/mwp-radar-sim
make && sudo make install
``` 

## Usage

```
$ mwp-radar-sim --help
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
```
### Options

* device : The name of the input device; all mwp device options are available (serial, IP, BT, USB, wifi, sockets etc.) e.g.
 - `/dev/ttyUSB0`, `/dev/ttyACM0` (usb ttl adapters)
 - `/dev/rfcomm0`, `00:14:03:11:35:16` (BT, by device or address)
 - `udp://:3000`, `tcp://random-host:23` (IP sockets)

  On Linux, `/dev/ttyUSB0` and `/dev/ttyACM0` are automatically probed.

* baud: Where required, default is `115200`

* centre: The central location / start point. A delimited string of decimal latitude and longitude, delimiters are ' ' or ','. Locale aware, default is `"54.353974 -4.5236"`.

* range : The maximum range before the simulated aircraft turn around, default is 500m.

* speed : Initial speed, default 15 m/s.

* alt: Initial altitude, default is 50m.

## Sample usage

Start mwp:

```
$ mwp  --centre "54.353974 -4.5236"  -d udp://:3000 --no-poll -a
```

For a local test, this uses UDP sockets.

For convenience, the `--centre` parameter matches the `mwp-radar-sim` default.

Then start the simulator:

```
$ mwp-radar-sim -d udp://localhost:3000
```







