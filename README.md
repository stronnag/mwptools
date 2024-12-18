mwptools revisited
==================

"A mission planner for the rest of us"

![mwp](docs/images/mwp4.png)

## Overview

**mwptools** provides a mission planner, ground control station, real time flight logger, terrain analysis, line of sight analysis and log replay / blackbox replay functions for [INAV](https://github.com/iNavFlight/inav) FC equipped model aircraft / UAS.

The current default (`master`) branch is the (re)implementation of mwp using Gtk4 / libshumate.

See the [migration guide](https://github.com/stronnag/mwptools/blob/master/docs/mwp-Gtk4-migration-guide.md) for dependencies (and migration from the legacy version (`legacy` branch).

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
* ADS-B using Dump1090 /  SBS-1 Basestation streaming TCP protocol (GA).
* Other mwp supported telemetry protocols (INAV UAS).

mwp provides logging and the replay of:

* mwp log files
* Blackbox logs
* OpenTX CSV (sdcard) logs
* BulletGCSS logs
* Ardupilot (`.bin`) log

Log replay requires tools from the [flightlog2x](https://github.com/stronnag/bbl2kml) project.

mwp also proivdes legacy suport for Multiwii navigation functions.

## User Guide

There is am [online user guide](https://stronnag.github.io/mwptools/).

## Tools

 * mwp : "A mission planner for the rest of us". Simple mission planning and monitoring. Mission Planning is provided for INAV and MW-NAV (MW 2.4+). Monitoring, logging and recording for INAV and MultiWii
 * Many other standalone tools to manage flight logs, maintain CLI `diff`s, analyse logs etc.

## Platforms and OS

The tools are designed to be portable and as far as possible platform and hardware agnostic. The suite is developed on Arch Linux and is additionally tested on Alpine (Edge), Debian (Trixie / Sid), Fedora (current)  and FreeBSD (current release) (at least). It is also possible to build and run mwp on MacOS (from mwptools 2024.11.20) and Windows (Msys2 / standalone installer from 2024.12.07).

mwp should  build and run on any platform that provides modern Gtk and POSIX APIs.

mwptools is tested on x86_64, ia32, aarch64 and riscv64 architectures (Linux / FreeBSD).

## Installation

See the [migration guide](docs/mwp-Gtk4-migration-guide.md) for dependencies (and migration from the legacy version).

```
meson setup _build --prefix=~/.local --strip
ninja -C _build install
```
## Licence

GPL v3 or later

## Contect

* IRC * [irc.libera.chat #mwptools](ircs://irc.libera.chat/mwptools)
* Github Issues and discussions
