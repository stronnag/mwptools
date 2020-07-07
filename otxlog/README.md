#Simple OpenTX log replay (and GPX generator)

## otxlog

Replay OpenTX log files / generate GPX from OpenTX logs.

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

Built and installed if the optional dependency 'go' is installed.

Required by `mwp` for the `Replay OTX ..` menu options.

## otx-split.rb

Splits a nulti-log CSV log into individual log files, based on time stamp. By default, a time difference of 30s causes a split.

$ ./otx-split.rb logfile.csv [interval]

where interval defaults to 30s.
