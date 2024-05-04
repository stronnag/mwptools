# ADS-B JSON Support tools

## Overview

mwp can accept ADS-B data in the [dump1090](https://github.com/flightaware/dump1090) JSON format.

As some versions of `dump1090` do not export this by default, it may be necessary to run a small daemon on the `dump1090` server. This daemon `jsacsrv` is small and uses few resources.

## `jsacsrv` daemon

This is built on the `dump1090` machine using the supplied `Makefile`. It requires a `vala` compiler and `make`. These are available via the package manager on most Linux and FreeBSD.

For Linux systems using `systemd`, a service file `jsacsrv.service` is provided. This assumes:

* There is a `dump1090` user
* The `jsacsrv` daemon is installed to `/usr/local/bin`
* The default `dump1090` JSON "aircraft" file is `/run/dump1090/aircraft.json`
* The default port of `37007` is acceptable.

The "aircraft" file and listening port can be provided to `jsacsrv`.

``` bash
$ jsacsrv --help
Usage:
  jsacsrv [OPTION?]  - dump1090 JSON server

Help Options:
  -h, --help       Show help options

Application Options:
  -p, --port       TCP Port
  -f, --acfile     File path
```

If you are using some versions of `readsb` (the wiedehopf readsb fork) or some versions of `dump1090`, they *may* supply the JSON data without requiring an external server.

## mwp setting

`mwp` uses the pseudo-URI `jsa://` to define the `dump1090-fa` JSON file as a radar device; `jsa://[host[:port]]`.

So for a machine `woozle` running `dump1090-fa` and `jsacsrv` with the default port:

``` bash
--radar-device jsa://woozle
```
