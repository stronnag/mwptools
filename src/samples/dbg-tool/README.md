# mwp dbg-tool

## Description

`dbg-tool` is a simple tool to support inav serial debugging, as described in [the inav documentation](https://github.com/iNavFlight/inav/blob/master/docs/development/serial_printf_debugging.md). It may be considered to be a much simplified, Linux specific analgoue to [@fiam's msp-tool](https://github.com/fiam/msp-tool).

## Features

* Linux only (uses `udev` for device discovery).
* Displays inav debug messages in a terminal
* Reboots the FC when 'R' is pressed
* Uses `udev` to discover the serial port.

## Usage

Just run the `dbg-tool`; it will discover USB serial devices as they are plugged / unplugged.

```
dbg-tool
```

For non-discoverable devices (e.g. Bluetooth), the device name can be provided:

```
dbg-tool /dev/rfcomm3
```

## Restrictions

Only one USB serial device can be active.
