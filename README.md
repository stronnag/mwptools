mwptools revisited
==================

"A mission planner for the rest of us"

![mwp](docs/images/mwp4.png)

## Overview

**mwptools** provides:

* Mission planning
* Ground control statio
* Real time flight logger
* Terrain analysis
* Line of sight analysis
* Log replay / blackbox replay
* Genera; aviation (ADSB) monitoring and alarm

for [INAV](https://github.com/iNavFlight/inav) FC equipped model aircraft / UAS.

mwp supports the following telemetry protocols:

* MSP (MultiWii Serial Protocol)
* LTM (Lightweight Telemetry)
* MAVLink (INAV subset)
* Smartport (direct /  via inverter / or from Multi-protocol Module)
* Crossfire (CRSF)
* Flysky AA (via Multi-protocol Module)
* [BulletGCCS MQTT](https://github.com/stronnag/mwptools/wiki/mqtt---bulletgcss-telemetry)

mwp supports the real-time display of adjacent aircraft (GA / other models) using:

* [INAV-radar](https://github.com/OlivierC-FR/ESP32-INAV-Radar/) (INAV UAS).
* MAVlink Traffic Report (e.g. full-size aviation, typically ADS-B via a device such as uAvionix PingRX) (GA).
* INAV `MSP2_ADSB_VEHICLE_LIST` (GA)
* ADS-B using Dump1090 /  SBS-1 Basestation streaming TCP protocol (GA) / JSON / Protobuf
* Internet ADSB providers
* Other mwp supported telemetry protocols (INAV UAS).

mwp provides logging and the replay of:

* mwp log files
* Blackbox logs
* OpenTX / EgdeTX CSV (sdcard) logs
* BulletGCSS logs
* Ardupilot (`.bin`) log

Log replay requires tools from the [flightlog2x](https://github.com/stronnag/bbl2kml) project.

mwp also proivdes legacy suport for Multiwii navigation functions.

## User Guide

There is an [online user guide](https://stronnag.github.io/mwptools/).

## Tools

 * mwp : "A mission planner for the rest of us". Simple mission planning and monitoring. Mission Planning is provided for INAV and MW-NAV (MW 2.4+). Monitoring, logging and recording for INAV and MultiWii
 * Many other standalone tools to manage flight logs, maintain CLI `diff`s, analyse logs etc.

## Platforms and OS

The tools are designed to be portable and as far as possible platform and hardware agnostic. The suite is developed on Arch Linux and is additionally tested on Debian (Trixie / Sid), Fedora (current), Void and FreeBSD (current release) (at least). It is also possible to build and run mwp on MacOS (from mwptools 2024.11.20) and Windows (Msys2 / standalone installer from 2024.12.07).

mwp should  build and run on any platform that provides modern GTK4 and POSIX APIs.

mwptools is tested on aarch64, riscv64 and x86_64 architectures om Linux and FreeBSD.

## Installation

Binary installers, Debian packages (`*.deb`) and a Windows installer are provided in the [Release Area](https://github.com/stronnag/mwptools/releases).

Otherwise the [online user guide](https://stronnag.github.io/mwptools/) provides dependency and build instructions.

There is a [migration guide](docs/mwp-Gtk4-migration-guide.md) describing migration from the legacy version.

```
meson setup _build --prefix=~/.local --strip
ninja -C _build install
```

## Licence

GPL v3 or later

## Contact

* IRC [irc.libera.chat #mwptools](ircs://irc.libera.chat/mwptools)
* Github [Issues](https://github.com/stronnag/mwptools/issues) and [discussions](https://github.com/stronnag/mwptools/discussions)
