# ADS-B JSON Support tools

## Overview

mwp can accept ADS-B data in the [readsb](https://github.com/Mictronics/readsb-protobuf) Protocol Buffer (protobuf) and [dump1090](https://github.com/flightaware/dump1090) JSON formats.

As `readsb` and `dump1090` typically require a third party web server to export these formats, mwptools provides daemons for these formats that can be run on the machine running `readsb` or `dump1090`. These daemons are small and uses few resources.

* `adsbpbsrv` for [readsb](https://github.com/Mictronics/readsb-protobuf) protobuf
* `jsacsrv` for [dump1090](https://github.com/flightaware/dump1090) JSON.



## `adsbpbsrv` daemon

This is built on the `readsb` machine using the supplied `Makefile`. It requires a `vala` compiler and `make`. These are available via the package manager on most Linux and FreeBSDs.

For Linux systems using `systemd`, a service file `adsbpbsrv.service` is provided. This assumes:

* There is a `readsb` user
* The `readsb` daemon is installed to `/usr/local/bin`
* The default `readsb` protobuf "aircraft" file is `/run/readsb/aircraft.pb`
* The default port of `38008` is acceptable.

The "aircraft" file and listening port can otherwise be provided to `adsbpbsrv`.

``` bash
$ adsbpbsrv --help
Usage:
  adsbpbsrv [OPTION?]  - readsb protobuf server

Help Options:
  -h, --help       Show help options

Application Options:
  -p, --port       TCP Port
  -f, --acfile     File path
```

## `jsacsrv` daemon

This is built on the `dump1090` machine using the supplied `Makefile`. It requires a `vala` compiler and `make`. These are available via the package manager on most Linux and FreeBSD.

For Linux systems using `systemd`, a service file `jsacsrv.service` is provided. This assumes:

* There is a `dump1090` user
* The `jsacsrv` daemon is installed to `/usr/local/bin`
* The default `dump1090` JSON "aircraft" file is `/run/dump1090/aircraft.json`
* The default port of `37007` is acceptable.

The "aircraft" file and listening port can otherwise be provided to `jsacsrv`.

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

## mwp setting

`mwp` uses the pseudo-URI `pba://` to define the `readsb` protobuf server and `jsa://` to define the `dump1090` JSON server.

So for a machine `woozle` running `readsb` and `adsbpbsrv` with the default port:

``` bash
--radar-device pba://woozle
```

Ando for a machine `jagular` running `dump1090` and `jsacsrv` with the default port:

``` bash
--radar-device jsa://jagular
```
