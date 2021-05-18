# Simple OpenTX log replay (and GPX generator)

## otxlog

Replay OpenTX log files / generate GPX from OpenTX logs.

Replay can generate either LTM (for use with mwp or other LTM aware ground station), or MQTT, targetted at the [BulletGCSS web API](https://bulletgcss.fpvsampa.com/)

```
$ otxlog
Usage of otxlog [options] [files ...]
Options:
Options:
  -b int
    	Baud rate (default 115200)
  -d string
    	LTM to serial device
  -dump
    	dump headers & exit
  -fast
    	fast replay
  -fd int
    	LTM to file descriptor (default -1)
  -gpx string
    	write gpx to file
  -index int
    	Log entry index (default 1)
  -list
    	list log data
  -metas
    	list metadata and exit
  -mqtt string
    	broker,topic
  -out string
    	output LTM to file
  -verbose
    	verbose LTM debug
```

options have a precedence:

* -dump
* -gpx
* -mqtt
* other output

Built and installed if the optional dependency 'go' is installed.

Required by `mwp` for the `Replay OTX ..` menu options.

`otxlog` has no dependency on any other part of `mwp` and may be used as a standalone tool (e.g. to generate GPX files from OTX logs) on any platform that provides golang. Standalone build as:

```
go build -ldflags "-w -s"
```

## MQTT option

The MQTT option (BulletGCSS) requires two comma separated parameters:

* A MQTT broker
* A MQTT topic

The [BulletGCSS wiki](https://github.com/danarrib/BulletGCSS/wiki) describes how these values are chosen; in general:

* It is safe to use `broker.emqx.io` as the MQTT broker, this is default is nothing appears before the comma in the otxlog `-mqtt` option.
* You should use a unique topic for publishing your own data, this is slash separated string, `foo/bar/quux/demo' which should include at least three elements.

Example:

```
$ otxlog -mqtt ",org/mwptools/mqtt/otxplayer" myopenTXlog.csv`
## the default broker is used ##
```

## otx-split.rb

Splits a nulti-log CSV log into individual log files, based on time stamp. By default, a time difference of 30s causes a split.

```
$ ./otx-split.rb logfile.csv [interval]
```
where interval defaults to 30s.
