package main

import (
	"flag"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"strings"
)

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [options] zonefile\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
	}

	showp := false
	verbose := false
	pline := false
	outfile := "-"
	cname := "Unknown"

	flag.BoolVar(&showp, "show-points", false, "show points in output")
	flag.BoolVar(&pline, "use-polyline", false, "show polylines (vice polygons)")
	flag.BoolVar(&verbose, "verbose", false, "dump out geozone structures")
	flag.StringVar(&outfile, "output", "-", "output file name ('-' => stdout)")
	flag.StringVar(&cname, "name", "Unknown", "craft name")
	flag.Parse()

	rest := flag.Args()
	if len(rest) > 0 {
		gzones, err := NewGeoZones(rest[0])
		if err == nil && len(gzones) > 0 {
			if verbose {
				for _, g := range gzones {
					fmt.Fprintf(os.Stderr, "%+v\n", g)
				}
			}
			kname := filepath.Base(rest[0])
			kname = strings.TrimSuffix(kname, path.Ext(kname))

			ndot := strings.LastIndex(kname, ".")
			if ndot != -1 {
				kname = kname[:ndot]
			}
			KMLFile(outfile, kname, gzones, showp, pline, cname)
		} else {
			fmt.Fprintln(os.Stderr, "No zones found")
			flag.Usage()
		}
	} else {
		flag.Usage()
	}
}
