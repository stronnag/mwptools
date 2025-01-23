# mwp Configuration

## Overview

{{ mwp }} stores configuration in a number of places, to some degree at the developer's whim, but also in accordance with the data item's volatility.

* Command line options
* Configuration Files
* dconf / gsettings

Each type is further discussed below.

## Command line options

Command line options provide a 'per instantiation' means to control {{ mwp }} behaviour; the current set of command line options may be viewed by running {{ mwp }} from the command line with the single option `--help`:

    $ mwp --help

Where it is required to give permanence to command line options, they can be added to the configuration file `$HOME/.config/mwp/cmdopts` (on Windows `$LOCALAPPDATA/mwp/cmdopts`), which is described in more detail in the following section.

Note that the documentation will habitually refer to the configuration base directory as `~/.config` as that is where it is found on the majority of OS; if you're using Windows, please adjust as necessary.

You can also use a system-wide "cmdopts" file, `/etc/default/mwp`. If this flie exists, it will read before the user's file.

* For singular options, any option in the user file will override the system file
* For multiply occurring options, e.g. `--radar-device`, definitions will be additive.
* Environment variables can be set from either or both files.

### Debug flags

The `--debug-flags` option takes a numeric value defines areas where additional debug information may be output.

| Value | Usage |
| ----- | ----- |
| 1     | Waypoints |
| 2     | Startup |
| 4     | MSP |
| 8     | ADHOC |
| 16    | RADAR |
| 32    | (unused) |
| 64    | SERIAL |
| 128   | VIDEO |
| 256   | GCS Location |
| 512   | Line of sight |
| 1024  | Radar |
| 2048  | Maps |

Values may be ORd together (so 4095 means all).

## Configuration Files

{{ mwp }} configuration files are stored in a standard directory `$HOME/.config/mwp`. This directory is created on first invocation if it does not exist.

### Platform differences

* POSIX XDG compliance :  User Configuration directory (`$XDG_CONFIG_HOME`)
* POSIX fallback : `$HOME/.config`
* Windows / Msys : `$LOCALAPPDATA` / `%LOCALAPPDATA%` / `$Env:LOCALAPPDATA`

The following files may be found in the `mwp` directory:

## `cmdopts`

The file `cmdopts` contains command line options that the user wishes to apply permanently (and conveniently when run from a launcher icon rather than the command line).

The file contains CLI options exactly as would be issued from the terminal. Options may be on separate lines, and blank lines and line prefixed with a hash '#' are ignored. For example:

In addition to options (`--`), the file may also contain environment variables e.g. `FOO=BAR`.

    # Default options for mwp
    --rings 50,20
    #--voice-command "spd-say -t female2 -e"
    #--debug-flags=2
    --dont-maximise
    #-S 8192
    # set the anonymous tile file.
    MWP_BLACK_TILE=/home/jrh/.config/mwp/mars.png

So here the only current, valid options are  `--rings 50,20 --dont-maximise`, and the [environment variable](#environment-variables) MWP_BLACK_TILE is set (for [anonymous maps](Black-Ops.md#custom-tile)).

The environment is set before any GTK / UI calls are made.

## Map Sources

{{ mwp }} provides by default:

* OpenStreetMap Mapnik
* OpenStreetMap Cycle Map
* OpenStreetMap Transport Map
* Maps for Free Relief
* Bing Maps (no API key required, for as long as the service remains available).
* MapBox (requires API key)
* ESRI Clarity

### Mapbox API Key management

In preparation for the announced removal of the Bing Maps service, `mwp` adds a `MapBox` entry where the user has acquired a [Mapbox API key](https://mapbox.com/).

This key may be either stored in the Desktop keyring (managed by `libsecret`) or as a plain text string in the `gsettings` database.

#### Keyring

Add to the keyring using `secret-tool` with the following attributes:

```
secret-tool store --label="Mapbox API" name mapbox-api-key domain org.stronnag.mwp
Password: *************************************************
```

#### Gsettings

Alternatively, the key can be added to the `gsettings` database:
```
 gsettings set org.stronnag.mwp mapbox-apikey 'pk.xxxxxxx'
 # where 'pk.xxxxxxx' is your MapBox API Key
```

Note that sadly `libshumate` creates a cache directory name from which the MapBox access token may be recovered, so there is little security / privacy gain by using the secret key-ring, alas. See [Gitlab issue](https://gitlab.gnome.org/GNOME/libshumate/-/issues/84).

## Additional Map Sources: `sources.json`

`sources.json` facilitates adding non-standard map sources to {{ mwp }}. See the  [anonymous maps](Black-Ops.md#custom-tile) section and comments in the source files in the `qproxy` directory.

Here is an example `mwptools/src/samples/sources.json`.

    {
     "sources" : [
      {
          "id": "OpenTopoMP",
		  "name": "OpenTopo",
		  "license": "(c) OSM",
		  "license_uri": "http://www.openstreetmap.org/copyright",
		  "min_zoom": 0,
		  "max_zoom": 19,
		  "tile_size": 256,
          "projection": "MERCATOR",
		  "uri_format": "http://map-proxy/mapproxy/tiles/1.0.0/opentopo/EPSG3857/{z}/{x}/{y}.png"
      },
      {
          "id": "LandscapeMP",
		  "name": "Landscape",
		  "license": "(c) OSM",
		  "license_uri": "http://www.openstreetmap.org/copyright",
		  "min_zoom": 0,
		  "max_zoom": 19,
		  "tile_size": 256,
          "projection": "MERCATOR",
		  "uri_format": "http://map-proxy/mapproxy/tiles/1.0.0/landscape/EPSG3857/{z}/{x}/{y}.png"
      },
      {
          "id": "CyclemapMP",
		  "name": "Cyclemap",
		  "license": "(c) OSM",
		  "license_uri": "http://www.openstreetmap.org/copyright",
		  "min_zoom": 0,
		  "max_zoom": 19,
		  "tile_size": 256,
          "projection": "MERCATOR",
		  "uri_format": "http://map-proxy/mapproxy/tiles/1.0.0/cyclemap/EPSG3857/{z}/{x}/{y}.png"
      },
      {
          "id": "Black",
          "name": "Black Tiles",
          "license": "(c) jh ",
          "license_uri": "http://daria.co.uk/",
          "min_zoom": 0,
          "max_zoom": 20,
		  "tile_size": 256,
          "projection": "MERCATOR",
          "spawn" : "bproxy"
      }
     ]
    }

See also [anonymous maps](Black-Ops.md#custom-tile) to customise the "black tile". The `spawn` stanza uses a proxy for non-TMS formats (see `mwptools/src/qproxy` for some examples).

## `volts.css`

`vol.css` contains alternate CSS themeing for the battery voltage dock item that may work better on dark desktop themes. An example file is provided as `mwp/vcol.css` which can be copied into `.config/mwp/`.

## `places`

The `places` (`~/.config/mwp/places`) file is a delimited (CSV) file that defines a list of "shortcut" home locations used by the "View / Centre on Position ..." menu item. It consists of a Name, Latitude, Longitude and optionally zoom level, separated by a `TAB`,`|`,`:` or `;`. Note that positions may be localised in the file and thus `.` is no longer recognised as a field separator.

Example `places`

    # mwp places name,lat,lon [,zoom]
    Beaulieu|50.8047104|-1.4942621|17
    Jurby:54.353974:-4.523600:-1

The user may maintain these files manually if used, or use the [graphic places editor](misc-ui-elements.md#favourite-places). The command line option `--centre` accepts a place name as well as a geographic coordinates.

## Panel settings

See the [migration guide](mwp-Gtk4-migration-guide.md) for information concerning:

* `~/.config/mwp/panel.conf`
* `~/.config/mwp/.paned`

## Dconf / gsettings

The underlying infrastructure used by {{ mwp }} has a facility for storing configuration items in a registry like store. This is used extensively by {{ mwp }}. The items can viewed and modified using a number of tools:

* {{ mwp }} preference dialogue (for a small subset of the items)
* The `dconf-editor` graphical settings editor (Linux, FreeBSD)
* The command line `gsettings` tool (Linux, FreeBSD, Windows)
* Regedit (Windows)
* Text Editor (MacOS)

### MacOS (exception)

Gtk on MacOS does not support `gsettings` in a useful way. As a work around, MacOS settings are stored in a text `.ini` file, `$HOME/.config/mwp/mwp.ini`.

### Linux, FreeBSD, Windows

For `gsettings` and `dconf-editor`, the name-space is `org.stronnag.mwp`, so to view the list of items:

    $ gsettings list-recursively  org.stronnag.mwp

and to list then get / set a single item:

    $ gsettings get org.stronnag.mwp log-save-path
    ..
    $ gsettings set org.stronnag.mwp log-save-path ~/flight-logs/

#### dconf-editor

This *may* not be installed by default, but should be available via the OS package manager / software centre.

<figure markdown>
![dconf editor](images/dconf-0.png){: width="50%" }
<figcaption>Initial dconf-editor showing all mwp settings</figcaption>
</figure>

<figure markdown>
![dconf editor](images/dconf-1.png){: width="50%" }
<figcaption>dconf-editor, editing a setting</figcaption>
</figure>

### List of mwp settings

### List of mwp settings

| Name | Summary | Description | Default |
| ---- | ------- | ----------- | ------ |
| adjust-tz | Adjust FC's TZ (and DST) | mwp should adjust FC's TZ (and DST) based on the local clock | true |
| ah-invert-roll | Invert AH roll | Set to true to invert roll in the AH (so it becomes an attitude indicator) | false |
| armed-msp-placebo | Antidote to armed menus placebo | Whether to suppress desensitising of MSP action items when armed. | false |
| arming-speak | speak arming states | whether to reporting arming state by audio | false |
| atexit | Something that is executed at exit | e.g. `gsettings set org.gnome.settings-daemon.plugins.power idle-dim true`. See also `manage-power` (and consider setting `manage-power` to `true` instead). | "" |
| atstart | Something that is executed at startup | e.g. `gsettings set org.gnome.settings-daemon.plugins.power idle-dim false`. See also `manage-power` (and consider setting to true). | "" |
| audio-on-arm | start audio on arm | start audio on arm (and stop on disarm) | true |
| auto-follow | set auto-follow | set auto-follow on start | true |
| auto-restore-mission | Whether to automatically import a mission in FC memory to MWP | If the FC holds a valid mission in memory, and there is no mission loaded into MWP, this setting controls whether MWP automatically downloads the mission. | false |
| autoload-geozones | Autoload geozones from FC | Autoload geozones from FC on connect, remove from display on disconnect | false |
| autoload-safehomes | Load safehomes on connect | . If true, then safehomes will be loaded from the FC on connection. | false |
| baudrate | Baud rate | Serial baud rate | 115200 |
| beep | Beep for alerts | Whether to emit an alert sound for alerts. | true |
| blackbox-decode | Name of the blackbox_decode application | Name of the blackbox_decode application (in case there are separate for iNav and betaflight) | "blackbox_decode" |
| bluez-disco | Use Bluetooth discovery | Only discovered Bluetooth serial devices with non-zero RSSI will be offered | true |
| default-altitude | Default altitude | Default Altitude for mission (m) | 20 |
| default-latitude | Default Latitude | Default Latitude when no GPS | 50.909528 |
| default-loiter | Default Loiter time | Default Loiter time | 30 |
| default-longitude | Default Longitude | Default Longitude when no GPS | -1.532936 |
| default-map | Default Map | Default map *key* | "" |
| default-nav-speed | Default Nav speed | Default Nav speed (m/s). For calculating durations only. | 2.5 |
| default-zoom | Default Map zoom | Default map zoom | 15 |
| delta-minspeed | Minimum speed for elapsed distance updates | Minimum speed for elapsed distance updates (m/s). Default is zero, which means the elapsed distance is always updated; larger values will take out hover / jitter movements. | 0.0 |
| device-names | Device names | A list of device names to be added to those that can be auto-discovered | [] |
| display-distance | Distance units | 0=metres, 1=feet, 2=yards | 0 |
| display-dms | Position display | Show positions as dd:mm:ss rather than decimal degrees | false |
| display-speed | Speed units | 0=metres/sec, 1=kilometres/hour, 2=miles/hour, 3=knots | 0 |
| dump-unknown | dump unknown | dump unknown message payload (debug aid) | false |
| espeak-voice | Default espeak voice | Default espeak voice (see espeak documentation) | "en" |
| flash-warn | Flash storage warning | If a dataflash is configured for black box, and this key is non-zero, a warning in generated if the data flash is greater than "flash-warn" percent full. | 0 |
| flite-voice-file | Default flite voice file | Default flite voice file (full path, *.flitevox), see flite documentation) | "" |
| forward | Types of message to forward | Types of message to forward (none, LTM, minLTM, minMAV, all) | "minLTM" |
| ga-alt | Units for GA Altiude | 0=m, 1=ft, 2=FL | 0 |
| ga-range | Units for GA Range | 0=m, 1=km, 2=miles, 3=nautical miles | 0 |
| ga-speed | Units for GA Speed | 0=m/s, 1=kph, 2=mph, 3=knots | 0 |
| geouser | User account on geonames.org | A user account to query geonames.org for blackbox log timezone info. A default account of 'mwptools' is provided; however users are requested to create their own account. | "mwptools" |
| gpsd-host | gpsd provider | Provider for GCS location via gpsd. Default is "localhost", can be set to other host name or IP address. Setting blank ("") disables. | "localhost" |
| gpsintvl | gps sanity time (m/s) | gps sanity time (m/s), check for current fix | 2000 |
| ident-limit | MSP_IDENT limit for MSP recognition | Timeout value in seconds for a MSP FC to reply to a MSP_INDENT probe. Effectively a timeout counter in seconds. Set to a negative value to disable. | 60 |
| ignore-nm | Ignore Network Manager | Set to true to always ignore NM status (may slow down startup) | false |
| kml-path | Directory for KML overlays | Directory for KML overlays, default = current directory | "" |
| led | GPS LED colour | GPS LED colour as well know string or #RRGGBB | "#60ff00" |
| log-on-arm | start logging on arm | start logging on arm (and stop on disarm) | false |
| log-path | Directory for replay log files | Directory for log files (for replay), default = current directory | "" |
| log-save-path | Directory for storing log files | Directory for log files (for save), default = current directory | "" |
| los-margin | Margin(m) for LOS Analysis | Margin(m) for LOS Analysis | 0 |
| mag-sanity | Enable mag sanity checking | mwp offers a primitive mag sanity checker that compares compass heading with GPS course over the ground using LTM (only). There are various hard-coded constraints (speed > 3m/s, certain flight modes) and two configurable parameters that should be set here in order to enable this check. The parameters are angular difference (⁰) and duration (s). The author finds a settings of 45,3 (i.e. 45⁰ over 3 seconds) works OK, detecting real instances (a momentarily breaking cable) and not reporting false positives. | "" |
| manage-power | manage power and screen | whether to manage idle and screen saver | false |
| map-sources | Additional Map sources | JSON file defining additional map sources | "" |
| mapbox-apikey | Mapbox API Key | Mapbox API key, enables Mapbox as a map Provider. Setting blank ("") disables. | "" |
| mavlink-sysid | Sysid for synthesised MAVLink | System ID in the range 2-255 (see [MAVlink documentation](https://ardupilot.org/dev/docs/mavlink-basics.html#message-format) and particularly the GCS guidance, 2nd paragraph _ibid_) | 106 |
| max-climb-angle | Maximum climb angle highlight for terrain analysis | If non-zero, any climb angles exceeding the specified value will be highlighted in Terrain Analysis Climb / Dive report. Note that the absolute value is taken as a positive (climb) angle | 0.0 |
| max-dive-angle | Maximum dive angle highlight for terrain analysis | If non-zero, any dive angles exceeding the specified value will be highlighted in Terrain Analysis Climb / Dive report. Note that the absolute value is taken as a negative (dive) angle | 0.0 |
| max-home-delta | home position delta (m) | Maximum variation of home position without verbal alert | 2.5 |
| max-radar-slots | Maximum number of aircraft | Maximum number of aircraft reported by iNav-radar | 4 |
| max-wps | Maximum number of WP supported | Maximum number of WP supported | 120 |
| min-dem-zoom | Minimum zoom for DEM loading | DEMs will not be fetched if zoom is below this value | 9 |
| misc-icon-size | Miscellaneous icon size | Size for miscellaneous icons (radar, GCS location) in pixels. -1 means the image's natural size (no scaling). | 32 |
| mission-meta-tag | use meta vice mwp in mission file | If true, the legacy 'mwp' tag is named 'meta' | false |
| mission-path | Directory for mission files | Directory for mission files, default = current directory | "" |
| msp2-adsb | MSP2_ADSB_VEHICLE_LIST usage | Options for requesting MSP2_ADSB_VEHICLE_LIST. "off": never request, "on:" always request, "auto:" heuristic based on serial settings / bandwidth | "off" |
| osd-mode | Data items overlaid on the map | 0 = none, 1 = current WP/Max WP, 2 = next WP distance and course. This is a mask, so 3 means both OSD items. | 3 |
| p-height | Internal setting |  | 720 |
| p-is-fullscreen | Internal setting |  | false |
| p-is-maximised | Internal setting |  | true |
| p-pane-width | Internal setting | Please do not change this unless you appreciate the consequences | 0 |
| p-width | Internal setting |  | 1280 |
| poll-timeout | Poll messages timeout (ms) | Timeout in milliseconds for telemetry poll messages. Note that timer loop has a resolution of 100ms. | 900 |
| pos-is-centre | Determines position label content | Whether the position label is the centre or pointer location | false |
| radar-alert-altitude | Altitude below which ADS-B alerts may be generated | Target altitude (metres) below which ADS-B proximity alerts may be generated. Requires that 'radar-alert-range' is also set (non-zero). Setting to 0 disables. Note that ADS-B altitudes are AMSL (or geoid). | 0 |
| radar-alert-range | Range below which ADS-B alerts may be generated | Target range (metres) below which ADS-B proximity alerts may be generated. Requires that 'radar-alert-altitude' is also set (non-zero). Setting to 0 disables. | 0 |
| radar-list-max-altitude | Maximum altitude for targets to show in the radar list view | Maximum altitude (metres) to include targets in the radar list view. Targets higher than this value will show only in the map view. This is mainly for ADS-B receivers where there is no need for high altitude targets to be shown. Setting to 0 disables. Note that ADS-B altitudes are AMSL (or geoid). | 0 |
| rings-colour | range rings colour | range rings colour as well know string or #RRGGBBAA | "#ffffff20" |
| rth-autoland | Set land on RTH waypoints | Automatically assert land on RTH waypoints | false |
| say-bearing | Whether audio report includes bearing | Whether audio report includes bearing | true |
| show-sticks | Whether to show sticks in log replay | If "yes", stick position is shown bottom right during log replay, if "no" , never shown. If "icon", then it shown iconified (bottom right) | "icon" |
| sidebar-type | Sidebar type | Options for the sidebar type. Unless you know better, leave at auto | "auto" |
| smartport-fuel-unit | User selected fuel type | Units label for smartport fuel (none, %, mAh, mWh) | "none" |
| speak-amps | When to speak amps/hr used | none, live-n, all-n n=1,2,4 : n = how often spoken (modulus basically) | "none" |
| speak-interval | Interval between voice prompts | Interval between voice prompts, 0 disables | 15 |
| speech-api | API for speech synthesis | espeak, speechd, flite. Only change this if you know you have the required development files at build time | "espeak" |
| speechd-voice | Default speechd voice | Default speechd voice (see speechd documentation) | "male1" |
| stats-timeout | timeout for flight statistics display (s) | Timeout before the flight statistics popup automatically closes. A value of 0 means no timeout. | 30 |
| symbol-scale | Symbol scale | Symbol scale factor, scales map symbols as multiplier. | 1.0 |
| touch-factor | Touch (Hi)DPI scaling | Adjustment factor for HiDpi touch screens (0 disable, often 1.5 or 2.0). | 0.0 |
| touch-scale | Touch symbol scale | Symbol scale factor, scales map symbols as multiplier (for touch screens) | 1.0 |
| uc-mission-tags | Upper case mission XML tags | If true, MISSION, VERSION and MISSIONITEM tags are upper case (for interoperability with legacy Android applications) | false |
| uilang | Language Handling | "en" do everything as English (UI numeric decimal points, voice), "ev" do voice as English (so say 'point' for decimals even when shown as 'comma') | "" |
| view-mode | UAV view mode | Options for model view | "inview" |
| vlevels | Voltage levels | Semi-colon(;) separated list of *cell* voltages values for transition between voltage label colours | "" |
| wp-dist-size | Font size (points) for OSD WP distance display | Font size (points) for OSD WP distance display | 56.0 |
| wp-spotlight | Style for the 'next waypoint' highlight | Defines RGBA colour for 'next way point' highlight | "#ffffff60" |
| wp-text-style | Style of text used for next WP display | Defines the way the WP numbers are displayed. Font, size and RGBA description (or well known name, with alpha) | "Sans 72/#ff000060" |
| zone-detect | Application to return timezone from location | If supplied, the application will be used to return the timezone (in preference to geonames.org). The application should take latitude and longitude as parameters. See samples/tzget.sh | "" |

### Replicating gsettings between machines or users

The standard system `dconf` application can be used to back up and restore the above `gsettings`.
To backup the settings:

    dconf dump /org/stronnag/mwp  >/tmp/mwp-dconf.txt

To restore the settings (overwrite). This could be for a different user or on a new machine.

    dconf load /org/stronnag/mwp  </tmp/mwp-dconf.txt

## Settings precedence and user updates

{{ mwp }} installs a number of icon files in `$prefix/share/mwp/pixmaps`. The user can override these by creating an eponymous file in the user configuration directory, `~/.config/mwp/pixmaps/`. Such user configurations are never over-written on upgrade.

For example, to replace a {{ mwp }} specific icon; i.e. replace the GCS Location icon (`$prefix/share/mwp/pixmaps/gcs.svg`) with a user defined file `~/.config/mwp/pixmaps/gcs.svg`.

While the file name must be consistent, the format does not have to be; the replacement could be be a PNG, rather than SVG; we're not MSDOS and file "extensions" are an advisory illusion.

### Example

e.g. replace the inav-radar icon.

    mkdir -p ~/config/mwp/pixmaps
    # copy the preview image
    cp ~/.local/share/mwp/pixmaps/preview.png  ~/config/mwp/pixmaps/
    # (optionally) resize it to 32x32 pixels
    mogrify -resize 80% ~/config/mwp/pixmaps/preview.png
    # and rename it, mwp doesn't care about the 'extension', this is not MSDOS:)
    mv  ~/config/mwp/pixmaps/preview.png  ~/config/mwp/pixmaps/inav-radar.svg
    # and verify ... perfect
    file ~/.config/mwp/pixmaps/inav-radar.svg
    /home/jrh/.config/mwp/pixmaps/inav-radar.svg: PNG image data, 32 x 32, 8-bit/color RGBA, non-interlaced

Note also that the resize step is no longer required, as {{ mwp }} scales the icon according to the `misc-icon-size` setting.

## Environment variables

{{ mwp }} recognises the following application specific environment variables

| Name  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;  | Usage |
| ------------- | ----- |
| `CFG_UGLY_XML` | Generate ugly multi-mission XML, so as not to confuse the inav configurator |
| `MWP_ARGS` | Extra command line arguments |
| `MWP_BLACK_TILE` | Specify a black tile to be used by the Black Tiles map proxy |
| `MWP_LOG_DIR` | Location of console logs ($HOME if undefined) |
| `MWP_PRINT_RAW` | If defined, output hex bytes from serial I/O |
| `MWP_TIME_FMT` | The time format for log output; by default "%FT%T%z", any GLib2 DateTime (strftime-like) format may be used; "%T.%f" works well on modern GLib. |

## Mime types for common file formats

{{ mwp }} adds XDG mime types for certain file types handled by mwp.

| Data Source | Mime Type | File Manager | DnD |
| ----------- | --------- | ------------ | ---- |
| Multiwii Mission (XML) | application/vnd.mw.mission | Yes [1](#mnote1) | Yes [2](#mnote2) |
| Blackbox log | application/vnd.blackbox.log | Yes | Yes |
| Mwp telemetry log | application/vnd.mwp.log | Yes | Yes |
| Multiwii mission (mwp JSON) | application/vnd.mwp.json.mission | Yes | Yes |
| OTX telemetry log | application/vnd.otx.telemetry.log | No | Yes |

!!! note "Notes:"

    <a name="mnote1">1.</a> The file manager (at least Nautilus / Gnome) will offer mwp as the default application to open the file.

    <a name="mnote2">2.</a>  DnD. The file can be dropped onto the mwp map and will be opened. The file may also be provided on the mwp command line without `--option`; e.g. `mwp --mission demo.mission` and `mwp demo.mission` will behave in the same way.
