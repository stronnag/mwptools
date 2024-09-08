# mwp caltool

## Description

`caltool` is a simple tool to for inav 6 point ACC calibration and mag calibration

## Features

* Enumerates USB / STM32 for serial device discovery.
* Performs inav 6 point ACC calibration
* Performs MAG calibration
* Displays calibration data

## Usage

```
caltool [device_name]
```

`device_name` is the name of the FC serial device (e.g. `/dev/ttyUSB0`, `/dev/ttyACM0`, `COM17`). On Linux, you may also use a Bluetooth device address (`xx:xx:xx:xx:xx:xx`).

If no device name is given, any extant USB / STM32 device will be auto-detected, at least on Linux and Windows. A device name specified on the command line will be used in preference to auto-detection. Note: On many OS, Bluetooth devices will not be auto-detected, so must be given as a command parameter.

### ACC Calibration

In order to perform ACC calibration:

* Verify FC is connected / recognised (version info has been shown)
* Place the ACC horizontally
* Press the 'A' key
* Follow the prompts, orientating the board on each axis, press the 'A' key when ready
* The results will be displayed when complete

### MAG calibration

In order to perform MAG calibration:

* Verify FC is connected / recognised (version info has been shown)
* Press the 'M' key
* Rotate the vehicle / mag around all axis
* The results will be displayed when complete

## Key press commands

* **A** : ACC calibration
* **M** : MAG calibration
* **V** : Fetch and display calibration data
* **R** : Reboot FC
* **Q** : Quit

## Installation

* `make`
* `make install prefix=~/.local` (install in `~/.local/bin`)
* or `sudo make install` (install in `/usr/local/bin`)
