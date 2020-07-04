Simple OpenTX log replay (and GPX generator)

```
$ otxlog
Usage of otxlog [options] [files ...]
Options:
  -b int
    	Baud rate (default 115200)
  -d string
    	LTM to serial device
  -dump
    	dump headers, exit
  -fast
    	fast replay (fixed 10ms inter-message delay)
  -fd int
    	LTM to file descriptor (default -1)
  -gpx string
    	write gpx to file
  -out string
    	output LTM to file
```

options have a precedence:

* -dump
* -gpx
* other output

Not built or installed by default.

Required by `mwp` for the `Replay OTX ..` menu options.
