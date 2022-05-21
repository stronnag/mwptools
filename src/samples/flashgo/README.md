# mwp flashgo

## Description

`flashgo` is a simple tool to download / erase data flash from INAV flight controllers.
Requires INAV 1.80 or later (MSPv2 support).

## Features

* Enumerates USB / STM32 for serial device discovery.
* Provides information on flash usage
* Downloads BBL from flash
* Erase flash

## Usage

```
flashgo [options] [device_name]
```

`device_name` is the name of the FC serial device (e.g. `/dev/ttyUSB0`, `/dev/ttyACM0`, `COM17`). On Linux, you may also use a Bluetooth device address (`xx:xx:xx:xx:xx:xx`).

If no device name is given, any extant USB / STM32 device will be auto-detected, at least on Linux and Windows. A device name specified on the command line will be used in preference to auto-detection. Note: On many OS, Bluetooth devices will not be auto-detected, so must be given as a command parameter.

### Options

```
$ flashgo --help
Usage of flashgo [options] [device_name]
  -dir string
    	output directory
  -erase
    	erase after download
  -file string
    	generated if not defined
  -info
    	only show info
  -only-erase
    	erase only
  -test
    	download whole flash regardess of usage
```

The default is to download the flash BBL (if the used size is > 0).
`-info` and `-only-erase` options do not download the flash contents.

If the file name is not provided, `-file BBL.TXT`, then a name is constructed of the form `bbl_YYYY-MM-DD_hhmmss.TXT` (i.e. current time stamp).

## Installation

* `make`
* `make install  (install in `~/.local/bin`)
* or `sudo make install prefix=/usr/local` (install in `/usr/local/bin`)
