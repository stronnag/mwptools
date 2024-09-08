# LTM player

## Intro

This program `play-ltm` replays a recorded LTM stream with assumed proper timing (i.e. 100 milliseconds between each 'A' frame).

## Use case

Sometimes, I can't be bothered to set the mwp / 3DR grpund station, but I'd still like an LTM record of the flight (especially if I'm testing WP missions, because LTM gives me the WP number and PH timed count down etc.). So I replace the 3DR connection on the aircraft with a serial logger (Open Log, Open Lager).

`play-ltm` will replay the LTM log into a serial device (for use in mwp), with correct timing.

## Usage

``` bash
$ play-ltm --help
Usage of ltm-player [options] [files ...]
  -b int
    	Baud rate (default 115200)
  -d string
    	Serial Device
  -v	Verbose
```

If no device is given, or -v, then decoded data is shown.

## Example

Start **mwp** ("random" port (54321), model type 8 == flying wing)
``` bash
mwp -d :54321 --no-poll -t 8 -a
```

Replay the log file (e.g LOG14138.TXT)

```
play-ltm -d udp://localhost:54321 LOG14138.TXT
```

## Build

``` bash
go build
# then copy play-ltm somewhere useful
```
