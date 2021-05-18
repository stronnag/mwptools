package main

import (
	"encoding/xml"
	gpx "github.com/twpayne/go-gpx"
	"os"
	"io"
	"fmt"
)

func openStdoutOrFile(path string) (io.WriteCloser, error) {
	var err error
	var w io.WriteCloser

	if len(path) == 0 || path == "-" {
		w = os.Stdout
	} else {
		w, err = os.Create(path)
	}
	return w, err
}

func GPXgen(filename string, s OTXSegment) {
	var wp []*gpx.WptType
	j := 0
	for _, b := range s.Recs {
		if b.Nsats > 0 {
			j += 1
			w0 := gpx.WptType{Lat: b.Lat,
				Lon:  b.Lon,
				Ele:  b.Alt,
				Time: b.Ts,
				Name: fmt.Sprintf("WP%d", j)}
			wp = append(wp, &w0)
		}
	}
	gfh, err := openStdoutOrFile(filename)
	if err == nil {
		g := &gpx.GPX{Version: "1.0", Creator: "otxreader",
			Trk: []*gpx.TrkType{&gpx.TrkType{TrkSeg: []*gpx.TrkSegType{&gpx.TrkSegType{TrkPt: wp}}}}}
		gfh.Write([]byte(xml.Header))
		g.WriteIndent(gfh, " ", " ")
		gfh.Write([]byte("\n"))
		gfh.Close()
	} else {
		fmt.Fprintf(os.Stderr, "gpx reader %s\n", err)
		os.Exit(-1)
	}
}
