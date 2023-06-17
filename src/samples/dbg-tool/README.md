# mwp dbg-tool

## Description

`dbg-tool` is a simple tool to support inav serial debugging, as described in [the inav documentation](https://github.com/iNavFlight/inav/blob/master/docs/development/serial_printf_debugging.md). It may be considered to be a much simplified replacement for [@fiam's msp-tool](https://github.com/fiam/msp-tool).

## Features

* Displays inav debug messages in a terminal
* Reboots the FC when 'R' is pressed
* Linux, uses `udev` to discover the serial port.

## Usage

Just run the `dbg-tool`; it will discover any extant plugged USB serial device, or provide the device node:

```
dbg-tool
# or
dbg-tool /dev/cuaU0
# or
dbg-tool COM17
```

For non-discoverable devices (e.g. Bluetooth), the device name must be provided:

```
dbg-tool /dev/rfcomm3
```

On Linux, `udev` is used to recognise device nodes as they are plugged / unplugged.

For non-Linux, the device given on the command line, or the initially dicovered device will be re-polled if it is unplugged / plugged.


## Restrictions

Only one USB serial device can be active.
