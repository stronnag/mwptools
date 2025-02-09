---
subtitle: A mission planner for the rest of us
---

# Overview

> Sweet dreams and flying machines[^1]

[^1]: *James Taylor, Fire and Rain. Full line is 'sweet dreams and flying machines in pieces on the ground', you may skip the final part*.

{{ mwp }} (originally "multi-wii planner") is a mission planner, ground control station and flight logger for MSP (Multiwiii Serial Protocol) compatible flight controller firmware ({{ inav }} and Multiwii at least).

From its MultiWii origins mwp has evolved to support navigation capabilities in {{ inav }}.

{{ inav }} is now the main development target, however MultiWii mission planning and ground control remains a supported function.

## Features

* [**Mission Planner**](mission-editor.md) : Supports all {{ inav }} and MultiWii mission planning functions, including all INAV extensions.
* [**Ground Control Station**](gcs-features.md) : (Near) real time ground control monitoring, using a wide range of [telemetry](#supported-protocols) options. Audio status reports.
* [**Monitoring and warning**](mwp-Radar-View.md) of other airspace users (INAV radar, manned aviation ADS-B)
* [**Flight log replay**](replay-tools.md)  (Blackbox, OTX/ETX logs, BulletGCSS)
* [**Embedded video**](mwp_video_player.md) (live and replay)
* **Support** functions
    * {{ inav }} [Safehome editor](mwp-safehomes-editor.md), [FW Auto-Land plans](mwp-safehomes-editor.md). [INAV8 Geozone editor](mwp-geozones.md).
	* [Survey / Search Area Planner](mwp-area-planner.md)
    * [Automatic mission shape](mission-editor.md#add-shape) generation, block moves, animated mission preview.
    * [Terrain Analysis](Mission-Elevation-Plot-and-Terrain-Analysis.md) with WP mission rewrite to safe elevation margins
    * [Line of sight Analysis](mwp-los-tool.md) along a WP mission file.
    * [Favourite sites manager](misc-ui-elements.md#favourite-places)
    * KML/KMZ static overlays
	* UBLOX AssistNow GPS data.

### Supported Protocols

{{ mwp }} supports the following [telemetry protocols](mwp-multi-procotol.md) :

* MSP (MultiWii Serial Protocol)
* LTM (Lightweight Telemetry)
* MAVLink (INAV telemetry 'push' subset)
* Smartport (direct /  via inverter / or from Multi-protocol Module)
* Crossfire (CRSF)
* Flysky AA (via Multi-protocol Module)
* [BulletGCSS MQTT](https://github.com/stronnag/mwptools/wiki/mqtt---bulletgcss-telemetry)

### Monitoring

{{ mwp }} also supports the [real-time display of adjacent aircraft](mwp-Radar-View.md) using:

* [INAV-radar](https://github.com/OlivierC-FR/ESP32-INAV-Radar/) (INAV UAS)
* SDR ADS-B (dump1090 / readsb / SBS1) live reports for general aviation
* Other SDR reporting procotols
* MAVlink Traffic Report / ADSB Vehicle (e.g. general aviation, typically ADS-B via a device such as uAvionix PingRX or Aerobits TT-SC1)
* `MSP2_ADSB_VEHICLE_LIST` (e.g. general aviation, typically ADS-B via a device such as uAvionix PingRX or Aerobits TT-SC1)
* Internet providers / aggregators using the REST `readsb` JSON format.

### Log replay formats

{{ mwp }} supports [replay](replay-tools.md) of:

* mwp log files (logged by mwp/GCS)
* Blackbox logs
* OpenTX and EdgeTX CSV (sdcard) logs
* BulletGCSS logs
* Ardupilot (`.bin`) log

Log replay requires tools from the [flightlog2x](https://github.com/stronnag/bbl2kml) project.

## Platforms and OS

The tools are designed to be portable and as far as possible platform and architecture agnostic. The suite is developed on Arch Linux and is also tested on Debian (Trixie / Sid), Alpine (Edge), Fedora (current)  and FreeBSD (current release). Being able to satisfy the required dependencies is more important than the actual distro / OS / platform. mwptools also runs on proprietary OS such as MacOS and Windows.

## Build and installation

Build and installation is described in the following sections:

* [Generic build and installation](Building-with-meson-and-ninja.md).

If you are migrating from the legacy (Gtk+-3.0) version to the extant (Gtk 4) version, you are advised to read the [migration guide](mwp-Gtk4-migration-guide.md) first.

## This document

This document describes the most recent (usually the development branch) version on Github.
Prior versions may be checked-out from their respective Github commits / branches / tags.
