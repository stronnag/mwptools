# mspmplex - MSP Multiplexer

## Introduction

`mspmplex` is a "proof of concept" serial / UDP multiplexer for INAV flight controllers. `mspmplex` arbitrates multiple UDP MSP consumers accessing a single flight controller, with some restrictions.

* The flight controller must be running INAV 8.0 or later
* Only MSPV2 is supported.
* Up to 64 clients are supported in a single session.
* A serial device must be opened before the multiplexing starts

## Details

`mspmplex`  uses the unused / undefined 6 `flag` bits of the MSPV2 message to encode a client number. Each unique inbound socket address is allocated to a numeric index (0-63).

* When a message is received via UDP, the message is rewritten as necessary with the allocated index masked into MSPV2 `flags`.
* When a response is received via serial, the socket address for the client is looked up from the index encoded in the MSPV2 `flags`.

## Clients

This has **only** been tested with `mwp` and the INAV Configurator.

* mwp 25.06.11 or later is required

Example:

```
# start the multiplexer (on host eeyore)
mspmplex -verbose 1

# first client (on eeyore):
mwp -d udp://localhost:27072

# second client (on another machine)
mwp -d udp://eeyore:27072

# on a machine other than "eeyore"
# Connect to udp://eeyore:27072
inav-configurator
```

## Usage

```
$ mspmplex --help

Usage of mspmplex [options] device [:port]
  -baudrate int
    	set baud rate (default 115200)
  -verbose int
    	verbosity (0:none, 1:open/close, >1: 1 + address map)
```

* Where possible serial services are auto-detected
* The default port is 27072

## Caveats

* Minimal error checking is implemented.
* Any MSPV1 message will get a MSPV2 error response from `mspmplex`; (message is never sent to the FC).
* Due to the bizarre way the INAV Configurator implements UDP (always *binds* to the local `INADDR_ANY`), it can only work if `mspmplex` and the INAV Configurator are on different hosts,

## Legal

(c) Jonathan Hudson 2025

GPL Version 3 or later
