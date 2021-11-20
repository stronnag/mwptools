# mwp-log-replay

Simple, standalone replay tool for data logs

Replays typically captured serial data from a log file.

mwp-log-replay understands (serial) device naming used by mwp:

* Serial Devices: `/dev/ttyUSB0`, `/dev/ttyACM0` (Linux), `/dev/cuaU0` (FreeBSD), `/dev//dev/tty.usbmodem00012345` (MacOS), `COM3` (Windows).
* TCP / UDP URIs: `udp://localhost:40042`, `tcp://localhost:40042`
* Bluetooth Address: `00:0B:0D:83:13:A9` (Linux)

mwp-log-replay understands the following log files:

* mwp "v2" binary logs
* mwp JSON logs
* Raw (data only) files

For the mwp logs, each entry in the log file has metadata (time, size, direction (in,out) that enables the data to be replayed with a similar timing characteristics to that of the recording.

For raw log files, the data is read in 16 byte chunks with a notional inter-chuck delay or 10ms.

# Log file

The log  file stores the raw data to be replayed. This may be either a record orientated binary file, delimited JSON records or just raw bytes. The format is auto-detected.

See [the mwp-serial-cap README](../mwp-serial-cap/README.md) for details of the mwp specific formats.

# Usage

```
$ mwp-log-replay --help
Usage of mwp-log-replay [options] input-file [outfile]
  -b int
    	Baud rate (default 115200)
  -d string
    	(serial) Device [device node, BT Addr (linux), udp/tcp URI]
  -delay float
    	Delay (s) for non-v2 logs (default 0.01)
  -raw
    	write raw log
  -wait-first
    	honour first delay
```

If no device name is given, hex formatted bytes are dumped to stdout.
If `-raw` is given, raw bytes (no metadata) are written to the optional output file, if provided.


# Building

mwp-log-replay is a Go language program, which should make it usable on most modern CPUs (ia32, x86-64, ARM) and OS (Linux, Windows, MacOS, *BSD) etc.

```
#### Go (golang) must be installed ####
go build
# or (if the ninja build tool is installed)
ninja
```
