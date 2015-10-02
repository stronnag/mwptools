cf-cli
======

"A simple tool to save and restore Cleanflight CLI dumps"

## Overview

**cf-cli** is a command line (cli) tool to save and restore dump files for
the Cleanflight FC.

In addtion to the command line **cf-cli**, there is a graphical user interface
version, **cf-cfi-ui**. This variant also understands the command line options
listed below, but may be run without any.

## Download / Snarf it

cf-cli is part of
[mwptools](https://github.com/stronnag/mwptools).  For users
on POSIX opertaing systems (Linux, OSX), just use
[github](https://github.com/stronnag/mwptools). If you don't want the
whole of mwptools, then:
```
$ cd cf-cli
$ make
$ sudo cp cf-cli cf-cli-ui /usr/local/bin/
```

For users of Microsoft Windows, you can find a [binary (executable)
distribution](http://www.zen35309.zen.co.uk/cf-cli/cf-cli-win32-1.04.zip).

The Windows binary archive expands as:
```
cf-cli\
cf-cli\cf-cli.bat
cf-cli\cf-cli-ui.bat
cf-cli\cleanflight-files
cf-cli\cf-cli.ico
cf-cli\README.pdf
cf-cli\binaries\...
cf-cli\source\...

```
The cf-cli directory may be placed anywhere on the file system, it is
recommended that you create a shortcut to the batch files using the
supplied icon file (cf-cli-ui.ico). You _must_ have write access to
the cleanflight-files directory. This can be relocated if desired, and
the CF_FILES environmnet variable updated in cf-cli-ui.bat.

Or you could download the [Windows' vala
compiler](http://www.tarnyko.net/dl/) and build it yourself.

_Note: cf-cli is a Windows build of a Linux command line
application. It is recommended that you run the CLI (cf-cli.bat) tool
within a CMD window, or via a modified BATch file, with PAUSE to
enable the user to view the status messages._

Dave Pitman has kindly created some more detailed instructions for the
Windows command line version
[cf-cli_quick_win.zip](https://www.dropbox.com/s/ahk1d24wbg3txc4/cf-cli_quick_win.zip).

For OSX, use the [tarnyko vala and GTK-3
port](http://www.tarnyko.net/dl/); There is an OSX command line
version, courtesy of a generous contributor via the #cleanflight IRC
channel. You will need to chmod +x the binary and satisfy any
home-brew glib dependencies (otool is your friend). [OSX binary](http://www.zen35309.zen.co.uk/cf-cli/osx/cf-cli)

## Platform notes

On Linux, cf-cli-ui will automatically detect CF devices (USB) and any
serial Bluetooth devices. On Windows, it is necessary to choose from a
dumb list of COM1: - COM9:, or enter the CF device name manually.

** Only Windows devices COM1: - COM9: are recognised **. This is a
   restriction of either the mingw cross compiler, NT namespaces and
   /or the author's ineptitude.

Additionally, on both platforms you can create a file of preferred
serial devices names:

Linux, defined by $XDG_CONFIG_HOME/cf-cli-ui, so typically:
```
~/.config/cf-cli-ui/cf-devices.txt
```
Windows, defined by "CSIDL_LOCAL_APPDATA"\cf-cli-ui, (or in the
cf-cli\ directory) so typically:
```
C:\users\USERNAME\Local Settings\Application Data\cf-cli-ui\cf-devices.txt
<install_path>\cf-cli\cf-devices.txt
```
This file (if present) just contains a list of candidate devices, one
per line, e.g.:
```
COM3:
COM6:
COM42:
```
Sample file cf-cli\\__cf-devices.txt. Edit and rename as needed.

## Usage
```
$ cf-cli --help
Usage:
  cf-cli [OPTION...] cleanflight_dump_file

Help Options:
  -h, --help               Show help options

Application Options:
  -d, --device             device name
  -o, --output-file        output file name
  -b, --baudrate           Baud rate
  --line-delay             (ms)
  -p, --profiles           Profile (0-2)
  -i, --presave            Save before setting
  -l, --logmsp             Log MSP
  -v, --verbose            Echo messages
  --acc                    cal acc
  -A, --all                All (profiles, merge aux settings, ie. "-p 0-2 -a")
  --mag                    cal mag
  -R, --noreboot           No Reboot
  -m, --merge-profiles     Generate a merged file for multiple profiles
  -a, --merge-auxp         Generate a merged file for multiple profiles with common aux settings
```

Simplest case, dump the current settings (e.g. using the Windows
device COM6:)

### Save Settings

```
$ ./cf-cli -d COM6:
2015-01-17T17:50:08+0000 Saving to cf_cli-2015-01-17_175003.txt
2015-01-17T17:50:09+0000 Done
```
Save all profile settings (again for Windows COM6:). On Linux, the
default device is `/dev/ttyUSB0`, so most likely you don't even need
'-d DEVNAME`. For OSX, you'll need to specify the device name.

Note that a default name is generated using the current timestamp,
unless you use `-o filename`.

#### User define save file ...

(so, Linux, where we default to `-d /dev/ttyUSB0`)
```
$ cf-cli -o my_fine_tri-2015-01-17.dat
2015-01-17T19:55:18+0000 Saving to my_fine_tri-2015-01-17.dat
2015-01-17T19:55:19+0000 Done

```
### Save multiple profiles

```
$ ./cf-cli -d COM6: -p 0-2
2015-01-17T17:48:39+0000 Saving to .\cf_cli-2015-01-17_174833_p0.txt
2015-01-17T17:48:39+0000 Saving to .\cf_cli-2015-01-17_174833_p1.txt
2015-01-17T17:48:40+0000 Saving to .\cf_cli-2015-01-17_174833_p2.txt
2015-01-17T17:48:41+0000 Done
```
### Restore the settings

```
$ ./cf-cli -d COM6: cf_cli-2015-01-17_174833_p0.txt
2015-01-17T17:49:12+0000 Reboot on defaults
2015-01-17T17:49:14+0000 Rebooted ...
2015-01-17T17:49:14+0000 Replaying cf_cli-2015-01-17_174833_p0.txt
2015-01-17T17:49:15+0000 Reboot on save
2015-01-17T17:49:18+0000 Saving to cf_cli-2015-01-17_174906.txt
2015-01-17T17:49:19+0000 Done
```
By default restoring doesn't save the setting prior to restore (as
it's most likely used after a re-flash), unless you specify
`-i`,`--presave`.

Note also that the settings are saved *after* the restoration; so you
get a record of any new setting from flashing new firmware.

### Merging profiles into one file

The `--merge-profiles` and `--merge-auxp` will merge profile specific
save files into a single file than can be replayed. If `--merge-auxp`
is specified, then the aux settings for the first profile are used
everywhere (mainly to protect the author from forgetting to set them
other than for profile 0).

As of 2015-01-25 20:45 UTC, save / restore for a merged profile sets
the default back to the first profile specified (--all or "-a -p 0-2").

```
$ cf-cli -o nw-new.txt --all # same as "-a -p 0-2"
09:30:37 Ready ...
09:30:37 Saving to ./nw-new_p0.txt
09:30:38 Saving to ./nw-new_p1.txt
09:30:39 Saving to ./nw-new_p2.txt
09:30:40 Merging ./nw-new_p0.txt
09:30:40 Merging ./nw-new_p1.txt
09:30:40 Merging ./nw-new_p2.txt
09:30:40 Done
```
For a merged profile, in addtion to the individual profile files
(nw-new_p0.txt .. nw-new_p2.txt above), there will be a combined file
with the global settings and the per-profile settings, in this case
"nw-new_merged.txt".
```
$ cf-cli --acc  nw-new_merged.txt # recal the acc as well
09:31:32 Ready ...
09:31:32 Reboot on defaults
09:31:35 Ready ...
09:31:35 Accelerometer calibration started
09:31:37 Accelerometer calibration finished
09:31:37 Replaying nw-new_merged.txt
09:32:40 Setting profile 1
09:32:40 Reboot on save
09:32:40 Done
```
Default profile is profile 0. (In the above example, profile 1 had
been set as default on the FC using the CF Configurator).

## Support

Well formed patches welcomed. As the author has limited access to
Windows platforms, Windows bug reports or enhancement requests without
patches are unlikely to be quickly resolved (windows images are
cross-compiled on Linux). Please raise
[github](https://github.com/stronnag/mwptools) issues as appropriate.

See also [python alternative](http://www.rcgroups.com/forums/showpost.php?p=30950883&postcount=4155)

## Licence

GPL2 or later

## Author

[Jonathan Hudson](mailto:jh+cf-cli@daria.co.uk). Principal support channel is
IRC freenode #cleanflight, where I sometimes lurk as user 'stronnag'.

## History: (see github, mwptools :)


2015-09-24 : Rebuild Windows version to pick up recent changes.

2015-09-17 : Rebuild Windows version to pick up recent changes. Tri-yaw removed, due to CF changes.

2015-07-17 : Improve I/O synchronisation for restore

2015-05-31 : Add OSX binary, add 1.9RC5 conversion tool  [dump-190+.rb](http://www.zen35309.zen.co.uk/cf-cli/dump-190+.rb).

2015-05-10 : Build the Windows binary again to reflect minor updates

2015-03-04 : Added simple tool to translate old dump serial setting to
	     the new 1.8.0+ format [dump-180+.rb](http://www.zen35309.zen.co.uk/cf-cli/dump-180+.rb).

2015-02-23 : Build from latest mwp sources
	     Add note on legacy device naming (reported by ethomas997)
	     Make cf-cli more resilient to slow comms startup e.g. BT

2015-02-14 : apply tri-yaw setting across all profiles

2015-02-13 : v1.0 !!
*	     Single (Windows) download (again)
*	     Reorganised file system layout
*	     Windows shortcuts to batch files should run from any location.

2015-02-11 : Add device names file, split out application and GTK3
archives.

2015-02-10 : GUI version.

2015-02-06 : Much more robust error handling on non-Linux platforms
(reported by Dave Pitman).
