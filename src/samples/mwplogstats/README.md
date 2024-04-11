# mwplogstats

Formatted information from mwp raw logs.

* metadata is written to `stdout` or user defined file
* MSP info is written to `stderr` or user define file

### Usage

``` sh
$ mwplogstats -help
Usage: mwplogstats [options] logfile
  -meta string
    	metadata output file name ('-' => stdout) (default "-")
  -msp string
    	msp output file name ('-' => stderr) (default "-")
```

```
mwplogstats mwp.udp_MWP_SERIAL_HOST_17071.2024-04-01T100032.raw -msp /tmp/msp.txt -meta /tmp/meta.txt
```
Without redirection to files, the screen output will be inter-leaved (which may be useful as well).

## MSP Output

Logged as version (MSP1/MSP2), direction ('<', ">'), CmdID (decimal, hex) and payload length. For pure text (MSP_NAME, MSP_BOXNAMES, MSP2_COMMON_SETTINGS), the payload is displayed as text.

    MSP1 < (100,0x64) paylen=0
	MSP1 ! (100,0x64) paylen=0
	MSP1 < (1,0x1) paylen=0
	MSP1 > (1,0x1) paylen=3 [0x00, 0x02, 0x05]
	MSP2 < (10,0xa) paylen=0
	MSP2 > (10,0xa) paylen=13 BENCHYMCTESTY
	MSP2 < (8208,0x2010) paylen=0
	MSP2 > (8208,0x2010) paylen=9 [0x00, 0x00, 0x00, 0x01, 0x00, 0x08, 0x00, 0x0c, 0x10]
	MSP2 < (4,0x4) paylen=0
	MSP2 > (4,0x4) paylen=15 [0x46, 0x46, 0x33, 0x35, 0x00, 0x00, 0x02, 0x03, 0x06, 0x57, 0x49, 0x4e, 0x47, 0x46, 0x43]

This sequence is from [mwp](https://github.com/stronnag/mwptools); as mwp supports all versions of INAV and Multiwii 2.4+, it first tries MSP1 MSP_IDENT (100), which fails on modern INAV (direction = '!').

MSP_NAME (10, 0xa) returns a text string, which is displayed as such.

## Meta Info output

For the metadata, the time offset (s), direction ('<'. '>'), size (bytes) and data read (hex dump) are shown. Note that this is entirely system / interface / I/O subsystem dependent and may not correspond to message boundaries.

    Offset: 0.001 dirn: < size: 6 [0x24, 0x4d, 0x3c, 0x00, 0x64, 0x64]
	Offset: 0.106 dirn: > size: 6 [0x24, 0x4d, 0x21, 0x00, 0x64, 0x64]
	Offset: 0.106 dirn: < size: 6 [0x24, 0x4d, 0x3c, 0x00, 0x01, 0x01]
	Offset: 0.145 dirn: > size: 9 [0x24, 0x4d, 0x3e, 0x03, 0x01, 0x00, 0x02, 0x05, 0x05]
	Offset: 0.146 dirn: < size: 9 [0x24, 0x58, 0x3c, 0x00, 0x0a, 0x00, 0x00, 0x00, 0xdd]
	Offset: 0.200 dirn: > size: 22 [0x24, 0x58, 0x3e, 0x00, 0x0a, 0x00, 0x0d, 0x00, 0x42, 0x45, 0x4e, 0x43, 0x48, 0x59, 0x4d, 0x43, 0x54, 0x45, 0x53, 0x54, 0x59, 0x6e]
	Offset: 0.200 dirn: < size: 9 [0x24, 0x58, 0x3c, 0x00, 0x10, 0x20, 0x00, 0x00, 0x9c]
	Offset: 0.213 dirn: > size: 18 [0x24, 0x58, 0x3e, 0x00, 0x10, 0x20, 0x09, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x08, 0x00, 0x0c, 0x10, 0x92]
	Offset: 0.213 dirn: < size: 9 [0x24, 0x58, 0x3c, 0x00, 0x04, 0x00, 0x00, 0x00, 0xc1]
	Offset: 0.229 dirn: > size: 24 [0x24, 0x58, 0x3e, 0x00, 0x04, 0x00, 0x0f, 0x00, 0x46, 0x46, 0x33, 0x35, 0x00, 0x00, 0x02, 0x03, 0x06, 0x57, 0x49, 0x4e, 0x47, 0x46, 0x43, 0x12]

## Building

Requires a Go (golang) compiler:

    go build -ldflags "-s -w"

For convenience, there is a `Makefile`

* `make` builds the executable
* `make install` builds the executable, installs to `~/.local` (or `$prefix`, `sudo make install prefix=/usr/local`)
* `make clean`

You can cross compile for any other Go supported OS / architecture, either via the `Makefile` or directly.

    GOOS=windows make
    GOOS=freebsd GOARCH=riscv64 make
	GOARCH=arm64 go build -ldflags "-s -w"

## Stuff

(c) Jonathan Hudson 2024. Unlicence / MIT / BSD / whatever passes for copyright retained but unrestricted distribution in any form.
