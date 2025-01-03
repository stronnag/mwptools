# Running mwp

## Video Tutorials

### Tutorial Playlist

All the developer's tutorial videos are in a [YouTube playlist](https://www.youtube.com/playlist?list=PLE_mnLfCdjvAH4pLe9HCqaWm682_r8NT3). These refer to the legacy version.

## Graphical User Interface

Once you've [built and / or installed](Building-with-meson-and-ninja.md) {{ mwp }}.

The install process installs an desktop icon and `mwp.desktop` application file ![icon](images/mwp_icon.svg)

  The `desktop` file tells the window manager where to find {{ mwp }} and on modern desktop environments (e.g. Gnome Shell, xfce, kde), {{ mwp }} will be added to the system application menu and / or 'finder'.

* It is also possible to run {{ mwp }} from a terminal, passing additional [options](mwp-Configuration.md) if required.
* Such [options can be added to a configuration file](mwp-Configuration.md) for persistence or use from the graphical icon.

## Touch Screen

The {{ mwp }}  map and map symbols are 'touch-aware'.

* You can drag map symbols using touch
* You can invoke "right mouse button" actions by a long press.

## Command line options

{{ mwp }}'s command line options may be displayed with the `--help` option:

```
$ mwp --help
Usage:
  mwp.exe [OPTION…]

Help Options:
  -h, --help                          Show help options
  --help-all                          Show all help options
  --help-gapplication                 Show GApplication options

Application Options:
  -a, --auto-connect                  Legacy, ignored)
  --build-id                          show build id
  --centre=position                   Centre position (lat lon or named place)
  -H, --centre-on-home                Centre on home
  --cli-file                          CLI File
  -c, --connect                       connect to first device (does not set auto flag)
  --debug-flags                       Debug flags (mask)
  --debug-help                        list debug flag values
  -d, --device=device-name            Serial device
  --dont-maximise                     Legacy, ignored
  --force-mag                         force mag for vehicle direction
  -t, --force-type=type-code_no       Model type
  -4, --force4                        Force ipv4
  --forward-to=device-name            forward telemetry to
  --full-screen                       Legacy, ignored
  -k, --kmlfile=file-name             KML file
  -m, --mission=file-name             Mission file
  -M, --mod-points=N                  Modulo points to show in GPS trail
  -S, --n-points=N                    Number of points shown in GPS trail
  -N, --no-poll                       don't poll for nav info
  -T, --no-trail                      don't display GPS trail
  --offline                           force offline proxy mode
  --radar-device=device-name          dedicated inav radar device
  -r, --raw-log                       log raw serial data to file
  --really-really-run-as-root         no reason to ever use this
  --rebase=lat,lon                    rebase location (for replay)
  --relaxed-msp                       don't check MSP direction flag
  -b, --replay-bbox=file-name         replay bbox log file
  -p, --replay-mwp=file-name          replay mwp log file
  --rings=number,interval             Range rings (number, interval(m)), e.g. --rings 10,20
  -s, --serial-device=device_name     Serial device
  -v, --version                       show version
  --voice-command=command string      External speech command
```

### Bash completion

{{ mwp }} installation also installs a 'bash completion' script.
Note this is only available after you log in, so on first install, it's only available after the *next* login.

This facilitates automatic command completion, so you don't have to remember all the options or be always typing `mwp --help`.

Typing `mwp ` and then `<TAB>` will first display the option lead `--`; then a subsequent `<TAB><TAB>` will display all the options. If one then typed `ra<TAB><TAB>`, it would complete to:

    $ mwp --ra
    --radar-device  --raw-log

Further entry (e.g. `d`) would complete the command (`--radar-device`).

### Adding options to a running mwp

Certain options, like `--replay-bbox`, `--mission` allow you to add a file to a running {{ mwp }}. So if {{ mwp }} was running, either from the command line or Desktop Environment icon, then (for example):

    mwp --mission file-i-forgot.mission

would load the mission `file-i-forgot.mission` into the running {{ mwp }} rather than starting a new instance.

### Drag and Drop

You can *drag and drop* relevant files onto the {{ mwp }} map:

* Blackbox Logs
* Mission Files
* KML Overlays
* CLI files

### CLI Files

{{ mwp }} can extract the following artefacts from a CLI File (`diff` or `dump`):

* Missions
* Safe Homes
* FW Approach definitions
* `set` parameters affecting visualisation (`nav_fw_land_approach_length`, `nav_fw_loiter_radius`).
* (future) GeoZones
