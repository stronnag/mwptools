# mwp dbg-tool

## Description

`dbg-tool` is a simple tool to support inav serial debugging, as described in [the inav documentation](https://github.com/iNavFlight/inav/blob/master/docs/development/serial_printf_debugging.md). It may be considered to be a much simplified, Linux specific analgoue to [@fiam's msp-tool](https://github.com/fiam/msp-tool).

## Features

* Displays inav debug messages in a terminal
* Reboots the FC when 'R' is pressed
* Uses `udev` to discover the serial port.

## Usage

Just run the `dbg-tool`; it will discover USB serial devices.

```
dbg-tool
```

## Restrictions

Only one USB serial device can be active.
