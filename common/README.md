cf-cli
======

"A simple tool to save and restore Cleanflight CLI dumps"

## Overview

cf-cli is a command line (cli) tool to save and restore dump files for
the Cleanflight FC. As well as saving and restoring dump files, the
tool understands the concept of reverse yaw for tricopters (and will
save and restore such settings).

## Snarf it

cf-cli is part of
[mwptools](https://github.com/stronnag/mwptools).  For users
on POSIX opertaing systems (Linux, OSX), just use
[github](https://github.com/stronnag/mwptools). If you don't want the
whole of mwptools, then:
```
$ cd common
$ make
$ sudo cp cf-cli /usr/local/bin/
```
For users of Microsoft Windows, you can find a [binary (executable)
distribution](http://www.zen35309.zen.co.uk/cf-cli/cf-cli-win32.zip). Or
you could download the Windows' vala compiler and build it
[yourself](http://www.tarnyko.net/dl/).

For OSX, use the [tarnyko vala port](http://www.tarnyko.net/dl/).

## Usage
```
$ cf-cli --help
Usage:
  cf-cli [OPTION...] cleanflight_dump_file

Help Options:
  -h, --help                  Show help options

Application Options:
  -d, --device                device name
  -o, --output-file           output file name
  -b, --baudrate              Baud rate
  -p, --profiles              Profile (0-2)
  -i, --presave               Save before setting
  -y, --force-tri-rev-yaw     Force tri reversed yaw
  -m, --merge-profiles        Generate a merged file for multiple profiles
  -a, --merge-auxp            Generate a merged file for multiple profiles with common aux settings
```

Simplest case, dump the current settings (e.g. using the Windows
device COM6:)

### Save Settings

```
$ ./cf-cli -d COM6:
2015-01-17T17:50:08+0000 Discovered Tri Yaw
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
2015-01-17T19:55:18+0000 Discovered Tri Yaw
2015-01-17T19:55:18+0000 Saving to my_fine_tri-2015-01-17.dat
2015-01-17T19:55:19+0000 Done

```

### Save multiple profiles

```
$ ./cf-cli -d COM6: -p 0-2
2015-01-17T17:48:38+0000 Discovered Tri Yaw
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
2015-01-17T17:49:18+0000 Set Tri Yaw
2015-01-17T17:49:18+0000 Saving to cf_cli-2015-01-17_174906.txt
2015-01-17T17:49:19+0000 Done
```
If you don't have a tricopter, you don't see the "Tri Yaw" messages.
By default restoring doesn't save the setting prior to restore (as
it's most likely used after a re-flash), unless you specify
`-i`,`--presave`.

Note also that the settings are saved *after* the restoration; so you
get a record of any new setting from flashing new firmware.

### Merging profiles into one file

The `--merge-profiles` and `--merge-auxp` will merge profile specific
save afiles into a single file than can be replayed. If `--merge-auxp`
is specified, then the aux settings for the first profile are used
everywhere (mainly to protect the author from forgetting to set them
other than for profile 0).

As of 2015-01-25 20:45 UTC, save / restore for a merged profile sets
the default back to the first profile specified.

````
$ cf-cli -o nw-new.txt -a -p 0-2
2015-01-25T20:46:40+0000 Saving to ./nw-new_p0.txt
2015-01-25T20:46:40+0000 Saving to ./nw-new_p1.txt
2015-01-25T20:46:41+0000 Saving to ./nw-new_p2.txt
2015-01-25T20:46:42+0000 Merging ./nw-new_p0.txt
2015-01-25T20:46:42+0000 Merging ./nw-new_p1.txt
2015-01-25T20:46:42+0000 Merging ./nw-new_p2.txt
2015-01-25T20:46:42+0000 Done

$ cf-cli  nw-new_merged.txt
2015-01-25T20:46:59+0000 Reboot on defaults
2015-01-25T20:47:01+0000 Rebooted ...
2015-01-25T20:47:01+0000 Replaying nw-new_merged.txt
2015-01-25T20:47:29+0000 Reboot on save
2015-01-25T20:47:32+0000 Done
````
Default profile is profile 0.

## Support

Well formed patches welcomed. As the author has limited access to
Windows platforms, Windows bug reports without patches are unlikely to
be quickly resolved (windows images are cross-compiled on
Linux). Please raise [github](https://github.com/stronnag/mwptools)
issues as appropriate.

## Licence

GPL2 or later

## Author

[Jonathan Hudson](mailto:jh+cf-cli@daria.co.uk). Principal support channel is
IRC freenode #cleanflight, where I sometimes lurk as user 'stronnag'.
