# mwp-serial-cap

Simple, standalone serial capture tool.

Captures serial data into a log file. Each entry in the log file has metadata (time, size, direction (in,out) that enables the data to be replayed with a similar timing characteristics to that of the recording.

# Usage

```
$ mwp-serial-cap --help
Usage of mwp-serial-cap [options] outfile
  -b int
    	Baud rate (default 115200)
  -d string
    	Serial Device
  -nometa
        Don't include metadata (packet size, timing) in capture file

$ mwp-serial-cap -d /dev/ttyUSB1 -b 57600 stuff.cap
^C
# Control-C to end the recording
```

On Linux, `/dev/ttyUSB0` and `/dev/ttyACMO` will be probed if no device name is given; on other platforms the device name must be supplied.

# Building

mwp-serial-cap is a Go language program, which should make it usable on most modern CPUs (ia32, x86-64, ARM) and OS (Linux, Windows, MacOS, *BSD) etc


```
#### Go (golang) must be installed ####

go build

```

# Capture file

The capture file stores the raw data received. If `-nometa` is omitted, then metadata is included that allows facimile playback by other mwp tools. If metadata is included (the default), then the following is written:

* A header "v2\n"
* Data encapsualted as a packed "pseudo-C" structure:

```
    struct {
       double time_offset; // seconds
       ushort data_size; // bytes
       uchar direction; // 'i' or 'o' (in or out, 'i' for a capture)
       uchar raw_bytes[data_size]; data read
    }
```
