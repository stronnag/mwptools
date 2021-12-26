---
subtitle: A mission planner for the rest of us
---

# Overview

> Sweet dreams and flying machines[^1]

[^1]: *James Taylor, Fire and Rain. Full line is 'sweet dreams and flying machines in pieces on the ground', you may skip the final part*.

{{ mwp }} (originally "multi-wii planner") is a mission planner, ground control station and flight logger for MSP (Multiwiii Serial Protocol) compatible flight controller firmware (Multiwii and {{ inav }} at least).

From its MultiWii origins mwp has evolved to support navigation capabilities in {{ inav }}.

{{ inav }} is now the main development target, however MultiWii mission planning and ground control remains a supported function.

## Features

* [**Mission Planner**](mission-editor.md) : Support all {{ inav }} and MultiWii mission planning functions, including all inav extensions.
* [**Ground Control Station**](gcs-features.md) : (Near) real time ground control monitoring, using a wide range of [telemetry](#supported-protocols) options. Audio status reports.
* [**Monitoring and warning**](mwp-Radar-View.md) of other airspace users (inav radar, manned aviation ADS-B)
* [**Flight log replay**](replay-tools.md)  (Blackbox, OTX/ETX logs, BulletGCSS)
* [**Embedded video**](mwp_video_player.md) (live and replay)
* **Support** functions
    * {{ inav }} [Safehome editor](mwp-safehomes-editor.md)
    * [Automatic mission shape](mission-editor.md#add-shape) generation, block moves, animated mission preview.
    * [Terrain Analysis](Mission-Elevation-Plot-and-Terrain-Analysis.md) with WP mission rewrite to safe margins
    * Favourite sites editor
    * KML/KMZ static overlays

### Supported Protocols

{{ mwp }} supports the following [telemetry protocols](mwp-multi-procotol.md) :

* MSP (MultiWii Serial Protocol)
* LTM (Lightweight Telemetry)
* MAVLink (iNav subset)
* Smartport (direct /  via inverter / or from Multi-protocol Module)
* Crossfire (CRSF)
* Flysky AA (via Multi-protocol Module)
* [BulletGCCS MQTT](https://github.com/stronnag/mwptools/wiki/mqtt---bulletgcss-telemetry)

### Monitoring

{{ mwp }} also supports the [real-time display of adjacent aircraft](mwp-Radar-View.md) using:

* [inav-radar](https://github.com/OlivierC-FR/ESP32-INAV-Radar/) (INAV UAS)
* MAVlink Traffic Report (e.g. full-size aviation, typically ADS-B via a device such as uAvionix PingRX)

### Log replay formats

{{ mwp }} supports [replay](replay-tools.md) of:

* mwp log files (logged by GCS)
* Blackbox logs
* OpenTX CSV (sdcard) logs
* BulletGCSS logs
* Ardupilot (`.bin`) log

Log replay requires tools from the [flightlog2x](https://github.com/stronnag/bbl2kml) project.

## Platforms and OS

The tools are designed to be portable and as far as possible platform and architecture agnostic. The suite is developed on Arch Linux and is tested on Debian (Bullseye, Sid), Ubuntu (latest and most recent LTS), Fedora (current)  and FreeBSD (current release). {{ mwp }} also runs on MS Windows, with Windows 11 / WSL-g is almost on feature parity with Linux / FreeBSD. Other (older) OS are unsupported, but may work (i.e. Debian 10 is used for the "release" builds).

## Build and installation

Build and installation is described in the following sections:

* [Generic build and installation](Building-with-meson-and-ninja.md) Linux, FreeBSD, Windows / WSL
    * Windows additional information ([Win11](mwp-in-Windows-11---WSL-G.md), [Win10](https://github.com/stronnag/mwptools/wiki/mwp-in-WSL) and [earlier](https://github.com/stronnag/mwptools/wiki/mwp-on-cygwin))

### Installation Tutorial

[Somewhat outdated](https://vimeo.com/256052320), if you follow this, please note that some of is much simplified by the later  [Generic build and installation](Building-with-meson-and-ninja.md) article.

<iframe src="https://player.vimeo.com/video/256052320?h=83d47b048d"  width="640" height="360" frameborder="0" allow="autoplay; fullscreen;  picture-in-picture" allowfullscreen></iframe>
