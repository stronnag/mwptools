mwptools
========

"A mission planner for the rest of us"

## Overview

mwptools provides a mission planner, [terrain analysis](https://github.com/stronnag/mwptools/wiki/Mission-Elevation-Plot-and-Terrain-Analysis), ground control station, real time flight logger and log replay / blackbox replay functions for the [inav](https://github.com/iNavFlight/inav) FC firmware.

mwptools supports the full set of inav and multiwii WP types.

![mwp](https://raw.githubusercontent.com/wiki/stronnag/mwptools/images/ltm-normal.png)

mwp supports the following telemetry protocols:

* MSP (MultiWii Serial Protocol)
* LTM (Lightweight Telemetry)
* MAVLink (iNav subset)
* Smartport (direct /  via inverter / or from Multi-protocol Module)
* Crossfire (CRSF)
* Flysky AA (via Multi-protocol Module)
* [BulletGCCS MQTT](https://github.com/stronnag/mwptools/wiki/mqtt---bulletgcss-telemetry)

mwp also supports the real-time display of adjacent aircraft using:

* [inav-radar](https://github.com/OlivierC-FR/ESP32-INAV-Radar/) (INAV UAS)
* MAVlink Traffic Report (e.g. full-size aviation, typically ADS-B via a device such as uAvionix PingRX)

mwp also provides logging and the replay of:

* mwp log files
* Blackbox logs
* OpenTX CSV (sdcard) logs
* BulletGCSS logs
* Ardupilot (`.bin`) log

Log replay requires tools from the [flightlog2x](https://github.com/stronnag/bbl2kml) project.

There is also an [inav](https://github.com/iNavFlight/inav) [Safehome editor](https://github.com/stronnag/mwptools/wiki/mwp-safehomes-editor).

In addition, mwp proivdes legacy suport for multiwii navigation functions.

## User Guide

PDF in `docs`, [online](https://stronnag.github.io/mwptools/).

## Tools

 * mwp : "A mission planner for the rest of us". Simple mission planning and monitoring. Mission Planning is provided for inav and MW-NAV (MW 2.4+). Monitoring, logging and recording for inav and MultiWii
 * Many standalone tools to manage flight logs, maintain CLI `diff`s, analyse logs etc.

## Platforms and OS

The tools are designed to be portable and as far as possible platform and architecture agnostic. The suite is developed on Arch Linux and is tested on Debian (Bullseye, Sid), Ubuntu (latest and most recent LTS), Fedora (current)  and FreeBSD (current release). mwp also runs on MS Windows, with Windows 11 / WSL-g is is pretty almost on feature parity with Linux / FreeBSD. Other (older) OS are unsupported, but may work (i.e. Debian 10).

mwp should  build and running on any platform that supports (recent versions of):

 * gtk+3.0 (3.18 or later);
 * meson / ninja
 * vala and gcc;
 * Clutter (software GL is fine);
 * libchamplain;
 * libespeak;
 * libgdl;
 * POSIX API

mwptools is tested on x86_64, ia32, Arm32 and aarch64 devices (Linux / FreeBSD).

* There is a "Release" debian package (x86_64, Debian, Ubuntu etc).
* Simple, ["one stop shop" build and install script](https://github.com/stronnag/mwptools/wiki/Building-with-meson-and-ninja/)
* AUR package 'mwptools-git' for Arch Linux.

It is also possible to build and run mwp on MS Windows using:

* Windows 11 / WSL-g [Installation instructions](https://github.com/stronnag/mwptools/wiki/mwp-in-Windows-11---WSL-G)
* [Cygwin](https://www.cygwin.com/) Recommended Windows solution prior to Windows 11
* Windows 10 / WSL (slow, less stable, less recommended)
* A virtual machine with a Linux guest.

The [wiki](https://github.com/stronnag/mwptools/wiki) provides further guidance.

### Other OS / See also

For OS not supported by mwp (e.g. MacOS, IOS, Andriod), see also [impload](https://github.com/stronnag/impload) for a mission format converter and upload application.

## Manual / User Guide

[mwp manual / user guide](https://stronnag.github.io/mwp-manual/)

## Installation

* Review / install the dependencies for your platform. The [documentation](docs/) directory lists dependencies for Fedora and Debian/Ubuntu like systems.

* [Installation Guide (wiki)](https://github.com/stronnag/mwptools/wiki/Building-with-meson-and-ninja/).

Support questions are best asked in the [RC Groups board](https://www.rcgroups.com/forums/showthread.php?2633708-mwp), the inav discord (off-topic) or telegram channels or Github discussions / issues.

### Changelog / Announcements

Important changes are [announced on the wiki](https://github.com/stronnag/mwptools/wiki/Recent-Changes).

### Updating

As mwptools makes no formal releases, you can update your installation from the master branch:

````
cd mwptools # the initial installation directory
git pull && cd build && ninja install
````

## Arch Linux

Arch users can install mwptools from the AUR package `mwptools-git`

## Compatibility

As well as supporting inav, mwp aims to be compatible with EOSBandi's WinGUI for MW. It used the same XML mission file format (with inav and mwp extensions) and aims to provide similar functionally where possible.

## Licence

GPL v3 or later

## Alternatives

In addition to [mwp](https://github.com/stronnag/mwptools), the following inav mission planners (and GCS in some cases) exist, in various states of usefulness, at least:

* [Inav Configurator (for inav 2.x)](https://github.com/iNavFlight/inav-configurator/tree/2.6.1), limited planning support
* [Inav Configurator (for inav 3.x)]( https://github.com/iNavFlight/inav-configurator), supports all current WP types. [Preview builds](http://seyrsnys.myzen.co.uk/inav-configurator-next/), may be augmented with [impload](https://github.com/stronnag/impload/) to upload missions to 2.x firmware.
* [Drone Helper](https://www.microsoft.com/en-us/p/drone-helper/9ncs8zwxn58x?activetab=pivot:overviewtab) (Windows 10)
* [Ezgui](https://play.google.com/store/apps/details?id=com.ezio.multiwii&hl=en_GB), [MissionPlanner for Inav](https://play.google.com/store/apps/details?id=com.eziosoft.ezgui.inav&hl=en) (Android) Unsupported, obsolete. May not work with either contemporary Android or inav firmware.
* [Mobile Flight](https://github.com/flyinghead/mobile-flight) (IOS) Unsupported, obsolete. May not work with either contemporary IOS or inav firmware.
* [Apmplanner2](https://ardupilot.org/planner2/) with [impload](https://github.com/stronnag/impload/). Ardupilot planner, missions can be uploaded to inav using [impload](https://github.com/stronnag/impload/).
* [qgroundcontrol](https://docs.qgroundcontrol.com/master/en/) with [impload](https://github.com/stronnag/impload/). Ardupilot planner, missions can be uploaded to inav using [impload](https://github.com/stronnag/impload/).
* [Side-Pilot](https://sidepilot.net/) with [impload](https://github.com/stronnag/impload)  (untested). Ardupilot mission planner and telemetry viewer for IOS.

The following alternatives exist for **mwp-area-planner** :

* iforce2d's [online planner](http://www.iforce2d.net/surveyplanner)
*  [qgroundcontrol](https://docs.qgroundcontrol.com/master/en/) with [impload](https://github.com/stronnag/impload/). Generic surveys and corridor plans are supported. [Example images](https://github.com/stronnag/impload/releases/tag/3.146.697).
