# Setting test tool

## Description

`clitest` and `msptest` are tools to test that settings can be saved repeatedly without loosing the settings.

The setting `nav_rth_home_altitude` is incremented sequentially from 0.

* Initialise the value to 0
* save, reboot
* Loop
  * read the value, compare with expected
  * increment the value
  * save (causing reboot)

`clitest` uses the CLI, `msptest` uses MSP.

## Features

* Linux only (uses `udev` for device discovery).
* Reports progress / issues

Go is an inherently cross-platform language; if one wished to implement this for any other operating system, it would merely be necessary to replace the Linux specific (udev) device notification (addition / removal) part.

## Usage

Build with `make`.

Just run the `clitest` or `msptest` tool; it will discover USB serial devices as they are plugged / unplugged.

```
clitest [LIMIT]
# or
msptest [LIMIT]
```
where LIMIT is the number of iterations; if not given or less than 1, then runs until the user stops it (CTRL-C).

## Example

```
$ ./clitest 32
Found: /dev/ttyACM0 (INAV, FURIOUS_F35-LIGHTNING)
Initalising ...
Remove: /dev/ttyACM0
Add: /dev/ttyACM0 (INAV, FURIOUS_F35-LIGHTNING)
Read value = 0 (0)
Remove: /dev/ttyACM0
Add: /dev/ttyACM0 (INAV, FURIOUS_F35-LIGHTNING)
Read value = 1 (1)
Remove: /dev/ttyACM0
...
Add: /dev/ttyACM0 (INAV, FURIOUS_F35-LIGHTNING)
Read value = 32 (32)
$
```

For MSP, we record the save time; this may take longer than you imagined (around 1.2s on F405).

```
$ msptest
...
Add device: /dev/ttyACM0 (INAV, FURIOUS_F35-LIGHTNING)
Read value = 0 (0)
Saving ...
Save took 1.217040242s
Remove device: /dev/ttyACM0
Add device: /dev/ttyACM0 (INAV, FURIOUS_F35-LIGHTNING)
Read value = 1 (1)
Saving ...
Save took 1.228760661s
Remove device: /dev/ttyACM0
```

## Other

The author has been unable to experience any lost settings issue with multiple 100 iterations of these (well-behaved) tools

The problem was later tracked down to a bug in the confgurator, not helped by less than strict protocol checking in the firmware.
