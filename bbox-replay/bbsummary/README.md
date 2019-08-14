# bbsummary

## Overview

A rust program to generate summary information from blackbox logs.


## Usage

```
$ bbsummary --help
Usage: bbsummary FILE [options]

Options:
    -d, --dump          Dumps headers and exits
    -i, --index IDX     Uses log index
    -h, --help          print this help menu
```

if `-d` is specified, the field names will be dumped out.

if `-i` is specifed, only the nominated log index will be processed.

One of more blackbox log files may be processed.

## Dependencies

* rust build environment

* `blackbox_decode`

## Building

```
$ cd mwptools/bbox-replay/bbsummary
$ cargo build --release
# application is target/release/bbsummary
```

## Limitations

May not process pre-iNav 2.0 current values correctly.

## Examples

### Single file with multiple logs

e.g. where there is a EEPROM used for logging:

```
$ bbsummary /t/inav/2019-08-05_arrow/BBL_2019-08-05_170107.TXT
Log      : BBL_2019-08-05_170107.TXT / 1
Craft    : "Dodos can fly" on 2019-08-05T11:45:44.416+01:00
Firmware : INAV 2.2.2 (142ee72c1) SPRACINGF3 of Jul 23 2019 16:40:02
Current  : 9.6 A at 04:26
Altitude : 66.9 m at 01:23
Speed    : 31.3 m/s at 01:34
Range    : 149.5 m at 03:26
Distance : 4944.2 m
Duration : 05:42
Disarm   : SWITCH

Log      : BBL_2019-08-05_170107.TXT / 2
Craft    : "Dodos can fly" on 2019-08-05T11:56:43.156+01:00
Firmware : INAV 2.2.2 (142ee72c1) SPRACINGF3 of Jul 23 2019 16:40:02
Current  : 9.6 A at 02:54
Altitude : 50.9 m at 04:02
Speed    : 30.9 m/s at 05:30
Range    : 114.0 m at 05:58
Distance : 4885.7 m
Duration : 06:11
Disarm   : SWITCH

Log      : BBL_2019-08-05_170107.TXT / 3
Craft    : ".
 on 2019-08-05T12:08:21.246+01:00
Firmware : INAV 2.2.2 (142ee72c1) SPRACINGF3 of Jul 23 2019 16:40:02
Current  : 9.3 A at 03:09
Altitude : 50.5 m at 02:42
Speed    : 30.9 m/s at 01:42
Range    : 124.7 m at 01:47
Distance : 3719.8 m
Duration : 05:09
Disarm   : NONE

```

The values for Current, Altitude, Speed and Range are the maximum values encounterd.

### Multiple files (which may or may not include multiple logs)

```
$ bbsummary /t/inav/2019-08-07_wingfc/LOG*
Log      : LOG13913.TXT / 1
Craft    : "Wing it!" on 2019-08-07T08:39:32.784+01:00
Firmware : INAV 2.2.2 (142ee72c1) WINGFC of Jul 23 2019 16:40:15
Current  : 9.0 A at 10:13
Altitude : 65.7 m at 04:40
Speed    : 28.0 m/s at 10:45
Range    : 152.1 m at 06:36
Distance : 11726.5 m
Duration : 12:27
Disarm   : SWITCH

Log      : LOG13914.TXT / 1
Craft    : "Wing it!" on 2019-08-07T08:55:19.654+01:00
Firmware : INAV 2.2.2 (142ee72c1) WINGFC of Jul 23 2019 16:40:15
Current  : 11.7 A at 05:57
Altitude : 89.3 m at 07:35
Speed    : 31.5 m/s at 06:12
Range    : 205.1 m at 06:09
Distance : 10374.4 m
Duration : 11:01
Disarm   : NONE

Log      : LOG13915.TXT / 1
Craft    : "Wing it!" on 2019-08-07T11:13:33.949+01:00
Firmware : INAV 2.2.2 (142ee72c1) WINGFC of Jul 23 2019 16:40:15
Current  : 11.9 A at 05:23
Altitude : 92.2 m at 08:38
Speed    : 35.5 m/s at 05:06
Range    : 183.9 m at 10:09
Distance : 9824.4 m
Duration : 10:53
Disarm   : SWITCH

```

## Esoteric stuff

As with other mwp blackbox tools, it's possible to specify additional parameters on a per-model basis to `blackbox_decode`; the main use case is using a virtual current sensor (as in the SPRF3 example above).

This is enabled via a configuration file `$HOME/.config/mwp/replay_ltm.json` (sic). Note in the above example, the SPRF3 wing has the vehicle name "Dodos can fly". In the file `$HOME/.config/mwp/replay_ltm.json`, the key "extra" is a map of vehcile name (regular expression) and extra arguments for `blackbox_decode`. 

In the following `$HOME/.config/mwp/replay_ltm.json`  file:

```
{
    "declination":-1,
    "extra":{"Dodos*":
	     "--simulate-current-meter --sim-current-meter-scale=45 --sim-current-meter-offset=10"}
}
```
When the model name is matched (`Dodos*` matches "Dodos can fly"), the the additiion arguments `--simulate-current-meter --sim-current-meter-scale=45 --sim-current-meter-offset=10` are added to the `blackbox_decode` command line.
 

