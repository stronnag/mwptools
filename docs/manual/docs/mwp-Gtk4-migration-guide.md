# mwp Migration Guide

This document describes the migration from legacy (Gtk+-3.0) mwp to contemporary (Gtk4) mwp.

![mwp](images/mwp4.png)

## System Requirements

### Supported OS

* Modern Open Source POSIX operating system, for example:
    * Alpine Linux 3.20+
    * Arch Linux
    * Debian "Trixie" / "Sid" (and derivatives)
    * Fedora 40+
    * FreeBSD 14+
	* Ubuntu 24.04 and later (and derivatives).

### Unsupported but usable OS

* MacOS (Ventura or later), requires `homebrew`. [Platform specifics](mwp-macos.md)
* Windows (10 or later), requires `MSys2`. [Platform specifics](mwp-windows-msys.md)

Note that most of the documentation assumes open source OS (Linux, FreeBSD) semantics. See the "Platform Specifics" documents for differences.

### Specific components

The following are minimum versions.

* Gtk4 (4.14)
* libsoup3 (3.2)
* libshumate (1.3)
* meson (1.40)
* blueprint-compiler (0.12.0)
* libvte4
* libadwaita-1 1.5
* libsecret-1
* librsvg

For replaying blackbox log, [bbl2kml](https://github.com/stronnag/bbl2kml) 1.0.24 or later is rquired.

## GSettings /DConf schema

The gsettings / dconf schema is now `/org/stronnag/mwp/`. The keys are (mainly) the same as for legacy mwp/gtk3 and may be migrated:

```
dconf dump /org/mwptools/planner/ | dconf load /org/stronnag/mwp/
```

### Gsettings Description

The full list of settings is maintained in a [separate article](mwpsettings.md), machine generated from the source code.

## libshumate

[libshumate](https://gitlab.gnome.org/GNOME/libshumate) is the replacement for the obsolete libchamplain. `libshumate` uses a different cache directory organisation compared to `libchamplain`. If required, you can bulk move (`rsync` etc.) your old `libchamplain` files to the new locations.

The old files are under `~/.cache/champlain/`, the new cache `~/.cache/shumate/`; the following table illustrates the naming for Bing and OpenStreetmap caches. Other caches follow a similar pattern.

| `libchamplain` | `libshumate` |
| -------------- | ------------ |
| `osm-mapnik`     | `https___tile_openstreetmap_org__z___x___y__png` |
| `BingProxy`  | `http___localhost_31897_Bing__z___x___y__png` |

## Map Sources

In preparation for the announced removal of the Bing Maps service, `mwp` adds new imagery sources:

* **Esri Clarity** : No registration required, some minor data quality affects.
* **Esri World Imagery** : No registration required, some minor data quality affects.
* **MapBox** : Requires registration, the user acquiring a [Mapbox API key](https://mapbox.com/). This key may be either stored in the Desktop keyring (managed by `libsecret`) or as a plain text string in the `gsettings` database.

### Keyring

Add to the MapBox key to the user keyring using `secret-tool` with the following attributes:

```
secret-tool store --label="Mapbox API" name mapbox-api-key domain org.stronnag.mwp
Password: *************************************************
```

### Gsettings

Alternatively, the key can be added to the `gsettings` database:
```
 gsettings set org.stronnag.mwp mapbox-apikey 'pk.xxxxxxx'
 # where 'pk.xxxxxxx' is your MapBox API Key
```

Note that sadly `libshumate` creates a cache directory name from which the MapBox access token may be recovered, so there is little security / privacy gain by using the secret key-ring, alas. See [Gitlab issue](https://gitlab.gnome.org/GNOME/libshumate/-/issues/84).

### Bing Services

While it lasts, the Bing services (no registration / key required) provide:

* Bing Aerial : Imagery with no annotations
* Bing Hybrid : Imagery with road / place annotations

## Side Panel

As `libgdl` is retired, a simple, bespoke panel comprising embedded resizeable panes has been implemented. The configuration may be user defined by a simple text file `~/.config/mwp/panel.conf`.

* The panel consists for four vertical panels
* The top panel can hold three horizontal panes
* The other panels can hold two panes.

Each entry is defined by a comma separated line defining the panel widget, the row (0-3) and the column (0-2) and an optional minimum size (only required for the artificial horizon). The default panel is defined (in the absence of a configuration file) as:

```
# default widgets
ahi,0,1,100
rssi, 1, 0
dirn, 1, 1
flight, 2, 0
volts, 3, 0
```

Which appears as:
![mwp4-panel-0](images/mwp4-panel-0.png)

The available panel widgets are named as:

| Name | Usage |
| ---- | ---- |
| `ahi` | Artificial horizon |
| `dirn` | Direction comparison |
| `flight` | "Flight View" Position / Velocity / Satellites etc, |
| `volts` | Battery information |
| `vario` | Vario indicator |
| `wind` | Wind Estimator (BBL replay only) |

No other legacy widgets have been migrated.

So using the following `~/.config/mwp/panel.conf`

```
# default + vario + wind widgets
ahi, 0, 1, 100
vario,0,2
rssi, 0, 0
wind, 1, 0
dirn, 1, 1
flight, 2, 0
volts, 3, 0
```

would appear as:
![mwp4-panel-1](images/mwp4-panel-1.png)

Note: If you change  `~/.config/mwp/panel.conf`, you should exit {{ mwp }} and delete  `~/.config/mwp/.paned` before restarting mwp.

## Coexistence

mwp (Gtk4) and legacy (Gtk+-3.0) versions can coexist.

* Install legacy mwp (Gtk+-3.0)
* Rename the executable (e.g. to mwp3)
* Install master mwp (Gtk4).

If you use any of the map proxies (`bproxy`, `gmproxy`), you must use the latest version.

## Display Variables / Tweaks

There are a couple of Gtk related environment variables that may affect the performance of mwp, particularly on older or less well supported GPUs:

* `GSK_RENDERER` : Recently the Gtk renderer default was changed from `gl` to `ngl` (4.14+) to `vulkan` (4.16+).
  On some older / less well supported GPUs it may be necessary to use the `cairo` renderer;  `cairo` is also necessary on the author's touch screen tablet for correct touch screen WP dragging. Note that there may well be trade offs: on one of the author's machines, WP dragging seems slightly snappier using the `cairo` `GSK_RENDERER`, however the CPU usage for BBL replay is much greater using `cairo` compared to `vulkan`.
* `GDK_BACKEND` : In the event that your hardware / software stack is almost hopelessly broken such that mwp is aborted with a Gdk message like  "Error 71 (Protocol error) dispatching to Wayland display", then setting this variable to `x11` may allow `mwp` to continue.

From mwp 24.10.28, mwp will set `GSK_RENDERER=cairo` for its own use if the OS or user has not previously set `GSK_RENDERER`.

The environment variable(s) may be set in `~/.config/mwp/cmdopts` for mwp exclusive use if required.
```
GSK_RENDERER=cairo
```

Otherwise, the variable(s) may be set in `/etc/environment`, `.profile` or a `.config/environment.d` file if required.

## Optional

If you use a map sources file in `~/.config/mwp`, you may optionally convert the `#X#` elements (for X, Y, Z) replacing with more standard `{x}` etc.

## Omissions

* ublox-geo (abandoned)

## OS Specifics

### Debian

For the Debian package runtime dependencies:

```

libadwaita-1-0 (>= 1.5~beta)
libc6 (>= 2.38)
libcairo2 (>= 1.2.4)
libgdk-pixbuf-2.0-0 (>= 2.22.0)
libglib2.0-0t64 (>= 2.80.0)
libgraphene-1.0-0 (>= 1.5.4)
libgstreamer1.0-0 (>= 1.6.0)
libgtk-4-1 (>= 4.13.5)
libgudev-1.0-0 (>= 146)
libjson-glib-1.0-0 (>= 1.5.2)
libpaho-mqtt1.3 (>= 1.3.0)
libpango-1.0-0 (>= 1.14.0)
libprotobuf-c1 (>= 1.0.1)
libsecret-1-0 (>= 0.7)
libshumate-1.0-1 (>= 1.0.0~alpha.1+20220818)
libsoup-3.0-0 (>= 3.3.1)
libtinfo6 (>= 6)
libvte-2.91-gtk4-0
libxml2 (>= 2.7.4)
librsvg
```
Example packages:

```
sudo apt install -y blueprint-compiler libprotobuf-c-dev \
  libvte-2.91-gtk4-dev libshumate-dev libpaho-mqtt-dev libgtk-4-dev \
  libadwaita-1-dev libsecret-1-dev librsvg2-dev
```

### Ubuntu

The Ubuntu 24.04 version of `meson` is too old. A more update version may be installed locally using `pipx`. For Ubuntu 24.10, the distro version is adequate.

```
sudo apt install pipx
pipx install meson
```

Other packages as for Debian.

### Fedora

Example package list:

```
sudo dnf5 install -y libshumate-devel vte291-gtk4-devel protobuf-c-devel \
	paho-c-devel blueprint-compiler gtk4-devel libsecret-devel
```

### MacOS

Requires mwptools 2024.11.20 or later.

* Use Homebrew to install required packages (names may be evinced from the Linux docs)
* Follow generic instructions for `meson` and `ninja`

## DBus

The DBus name / path are changed to map the application Id; e.g. `org.stronnag.mwp` and  `/org/stronnag/mwp`. A few of the DBus interfaces have been enhanced.
