package main

import (
	"os"
	"flag"
	"fmt"
	"strings"
)

var (
	baud    = flag.Int("b", 115200, "Baud rate")
	device  = flag.String("d", "", "LTM to serial device")
	fd      = flag.Int("fd", -1, "LTM to file descriptor")
	output  = flag.String("out", "", "output LTM to file")
	gpxout  = flag.String("gpx", "", "write gpx to file")
	dump    = flag.Bool("dump", false, "dump headers & exit")
	fast    = flag.Bool("fast", false, "fast replay")
	verbose = flag.Bool("verbose", false, "verbose LTM debug")
	idx     = flag.Int("index", 1, "Log entry index")
	metas   = flag.Bool("metas", false, "list metadata and exit")
	list    = flag.Bool("list", false, "list log data")
	mqttdef = flag.String("mqtt", "", "broker,topic")
)

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of otxlog [options] [files ...]\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
	}

	flag.Parse()
	files := flag.Args()
	if len(files) == 0 {
		flag.Usage()
		os.Exit(-1)
	}

	o := NewOTX(files[0])
	m, err := o.GetMetas()
	if err == nil {
		if *metas {
			for _, mx := range m {
				fmt.Printf("%d,%s,%s,%d,%d,%.0f,%x\n", mx.Index, mx.Logname, mx.Date, mx.Start, mx.End, mx.Duration.Seconds(), mx.Flags)
			}
		} else if *dump {
			o.Dump()
		} else if *idx > 0 && *idx <= len(m) {
			recs := o.Reader(m[*idx-1])
			if len(*gpxout) > 0 {
				GPXgen(*gpxout, recs)
			} else if *list {
				Listgen(recs)
			} else if *mqttdef != "" {
				mq := strings.Split(*mqttdef, ",")
				broker := ""
				topic := ""
				if len(mq) > 1 {
					broker = mq[0]
					if len(mq) >= 2 {
						topic = mq[1]
					}
					MQTTGen(broker, topic, recs)
				}
			} else {
				var s *MSPSerial
				if *fd > 0 {
					s = NewMSPFd(*fd)
				} else if len(*device) > 0 {
					s = NewMSPSerial(*device, *baud)
				} else if len(*output) > 0 {
					s = NewMSPFile(*output)
				} else {
					fmt.Fprintf(os.Stderr, "No output specified\n")
					os.Exit(-1)
				}
				LTMGen(s, recs, *verbose, *fast)
			}
		}
	}
}
