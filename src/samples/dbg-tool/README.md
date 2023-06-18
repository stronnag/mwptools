# mwp dbg-tool

## Description

`dbg-tool` is a simple tool to support inav serial debugging, as described in [the inav documentation](https://github.com/iNavFlight/inav/blob/master/docs/development/serial_printf_debugging.md). It may be considered to be a much simplified replacement for [@fiam's msp-tool](https://github.com/fiam/msp-tool).

## Features

* Displays inav debug messages in a terminal
* Reboots the FC when 'R' is pressed
* Linux, uses `udev` to discover the serial port.

## Usage

Just run the `dbg-tool`; it will discover any extant plugged USB serial device, or provide the device node. The baudrate defaults to 115200, otherwise it may be specified:

```
dbg-tool
# or
dbg-tool /dev/cuaU0
# or
dbg-tool COM17
# or (good luck ...)
dbg-tool -baudrate 9600
```

For non-discover-able devices (e.g. Bluetooth), the device name must be provided:

```
dbg-tool /dev/rfcomm3
```

On Linux, `udev` is used to recognise device nodes as they are plugged / unplugged.

For non-Linux, the device given on the command line, or the initially discovered device will be re-polled if it is unplugged / plugged.

## Example output

```
[dbg-tool] 15:13:44.806365 Opened /dev/ttyACM0
[dbg-tool] 15:13:45.655200 DBG: [     1.409] Memory allocated. Free memory = 1828
[dbg-tool] 15:13:45.655273 DBG: [     1.409] GYRO CONFIG { 0, 4000 } -> { 0, 4000}; regs 0x00, 0x01
[dbg-tool] 15:13:47.862979 Variant: INAV (3.056592879s)
[dbg-tool] 15:13:47.879039 Version: 7.0.0 (3.072648158s)
[dbg-tool] 15:13:49.110944 DBG: [     4.872] Gyro calibration complete (-16, -12, 0)
[dbg-tool] 15:13:51.111053 DBG: [     6.873] Gravity calibration complete (932)
[dbg-tool] 15:13:51.862906 DBG: [     7.627] Barometer calibration complete (6701)
```

* MSP Processing is available after c. 3 seconds
* The calibration process takes nearly 8 seconds

## Example Settings

For the above,the following was specifically set in the CLI:

```
serial 20 32769 115200 115200 0 115200

set log_level = DEBUG
set log_topics = 4294967295
```

## Restrictions

Only one USB serial device can be active.
