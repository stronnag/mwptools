# mwp-serial-cap

Simple, standalone serial capture tool.

Captures serial data into a log file. Each entry in the log file has metadata (time, size, direction (in,out) that enables the data to be replayed with a similar timing characteristics to that of the recording.

# Usage

```
$ mwp-serial-cap --help
Usage of mwp-serial-cap [options] file
  -b int
    	Baud rate (default 115200)
  -d string
    	Serial Device
  -js
    	JSON stream
  -nometa
    	No metadata

$ mwp-serial-cap -d /dev/ttyUSB1 -b 57600 stuff.cap
^C
# Control-C to end the recording


### BT device, by address (Linux)
$ mwp-serial-cap -d 35:53:17:04:14:BA -b 57600 stuff.cap
2021/11/21 08:45:36 Using device 35:53:17:04:14:BA
Read ( 11)	:     15841 [22.52s]^C
# Control-C to end the recording
```

On Linux, `/dev/ttyUSB0` and `/dev/ttyACMO` will be probed if no device name is given; otherwise, and always on other platforms, the device name must be supplied.

All mwptools serial transports are available (Bluetooth, IP (TCP and UDP)) in addition to USB-TTL.

# Building

mwp-serial-cap is a Go language program, which should make it usable on most modern CPUs (ia32, x86-64, ARM) and OS (Linux, Windows, MacOS, *BSD) etc

```
#### Go (golang) must be installed ####

go mod tidy
go build
```

There is also a ninja build file.

```
# default install in ~/.local/bin, most modern distros support this
ninja install
```

# Capture file

The capture file stores the raw data received. This may be either a record orientated binary file or delimited JSON records.

If `-nometa` is omitted, then metadata is included that allows facimile playback by other mwp tools. If metadata is included (the default), then the following is written:

* A header "v2\n" `[0x76 0x32 0x0a]`
* Data encapsualted as a packed "pseudo-C" structure:

```
    struct {
       double time_offset; // seconds (IEEE 754 double)
       ushort data_size; // bytes
       uchar direction; // 'i' or 'o' (in or out, 'i' for a capture)
       uchar raw_bytes[data_size]; data read
    }
```

All binary fields are host native-endian, typically little-endian on modern CPUs.

If the `-js` (JSON) option is selected, a JSON file is created, containing LF (0x0a) delimited lines of a JSON structure, for example:
```
{"stamp":0.023195534,"length":36,"direction":105,"rawdata":"/hxTAfoeq+sBAPytAL2mkqs7QK6AvT+CGL2evDi8ynDFPCVR"}
```
* `stamp`: elapsed time (seconds)
* `length`: raw data size (bytes)
* `direction`: 105 ('i') or 111 ('o'), interpreted as above
* `rawdata`: JSON encoded byte array

`-js` has precedence over `-nometa`.

## Replay

Captured log files may be replayed using the [mwp-log-replay](../mwp-log-replay/README.md) replay tool.
