package main

import (
	"encoding/xml"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	"time"
)

import (
	"geo"
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

func split(s string, separators []rune) []string {
	f := func(r rune) bool {
		for _, s := range separators {
			if r == s {
				return true
			}
		}
		return false
	}
	return strings.FieldsFunc(s, f)
}

type Point struct {
	lat float64
	lon float64
}

type Frob struct {
	orig  Point
	reloc Point
}

func NewFrob(olat, olon, rlat, rlon float64) *Frob {
	return &Frob{
		Point{olat, olon},
		Point{rlat, rlon},
	}
}

func (f *Frob) set_origin(olat, olon float64) {
	f.orig.lat = olat
	f.orig.lon = olon
}

func (f *Frob) set_rebase(rlat, rlon float64) {
	f.reloc.lat = rlat
	f.reloc.lon = rlon
}

func (f *Frob) diff_pos(lat, lon float64) (float64, float64) {
	return geo.Csedist(f.orig.lat, f.orig.lon, lat, lon)
}

func (f *Frob) to_pos(c, d float64) (float64, float64) {
	return geo.Posit(f.reloc.lat, f.reloc.lon, c, d)
}

func (f *Frob) relocate(lat, lon float64) (float64, float64) {
	c, d := geo.Csedist(f.orig.lat, f.orig.lon, lat, lon)
	return geo.Posit(f.reloc.lat, f.reloc.lon, c, d)
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of movemission --rebase=lat,lon [options] missionfile\n")
		flag.PrintDefaults()
	}

	basepos := ""
	outfile := "-"
	flag.StringVar(&basepos, "rebase", basepos, "rebase to")
	flag.StringVar(&outfile, "output", outfile, "Output file")
	flag.Parse()
	files := flag.Args()
	if len(files) == 0 || basepos == "" {
		flag.Usage()
		os.Exit(-1)
	}

	nlat := 0.0
	nlon := 0.0
	var err error
	parts := split(basepos, []rune{'/', ':', ';', ' ', ','})
	if len(parts) >= 2 {
		nlat, err = strconv.ParseFloat(parts[0], 64)
		if err == nil {
			nlon, err = strconv.ParseFloat(parts[1], 64)
		}
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "Pos err\n")
		return
	}

	mm, err := ReadMissionFile(files[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Mission err %+v\n", err)
		return
	}

	f := NewFrob(0, 0, nlat, nlon)

	for k := 0; k < len(mm.Segment); k++ {
		needoffset := true
		mm.Segment[k].Metadata.Generator = "movemission (mwptools)"
		mm.Segment[k].Metadata.Stamp = time.Now().Format(time.RFC3339)

		if mm.Segment[k].Metadata.Homey != 0.0 && mm.Segment[k].Metadata.Homex != 0.0 {
			f.set_origin(mm.Segment[k].Metadata.Homey, mm.Segment[k].Metadata.Homex)
			mm.Segment[k].Metadata.Homey = nlat
			mm.Segment[k].Metadata.Homex = nlon
			mm.Segment[k].Metadata.Cy, mm.Segment[k].Metadata.Cx = f.relocate(mm.Segment[k].Metadata.Cy, mm.Segment[k].Metadata.Cx)
			needoffset = false
		}

		for i := 0; i < len(mm.Segment[k].MissionItems); i++ {
			if needoffset && mm.Segment[k].MissionItems[i].is_GeoPoint() {
				f.set_origin(mm.Segment[k].MissionItems[i].Lat, mm.Segment[k].MissionItems[i].Lon)
				mm.Segment[k].MissionItems[i].Lat = nlat
				mm.Segment[k].MissionItems[i].Lon = nlon
				needoffset = false
			} else {
				mm.Segment[k].MissionItems[i].Lat, mm.Segment[k].MissionItems[i].Lon = f.relocate(mm.Segment[k].MissionItems[i].Lat, mm.Segment[k].MissionItems[i].Lon)
			}
		}
	}

	mm.Comment = fmt.Sprintf("Rebased on %.6f %.6f", nlat, nlon)
	mm.Version.Value = "42"
	data, err := xml.MarshalIndent(mm, " ", "  ")
	if err != nil {
		log.Fatal(err)
	} else {
		fh, _ := openStdoutOrFile(outfile)
		defer fh.Close()
		fh.Write([]byte(xml.Header))
		fh.Write(data)
		fh.Write([]byte("\n"))
	}
}
