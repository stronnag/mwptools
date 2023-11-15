package main

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
)

const DEM_NODATA = -32678.0

type hgtHandle struct {
	fp    *os.File
	blat  int
	blon  int
	width int
	arc   int
	fname string
}

type hgtDb struct {
	hgts []*hgtHandle
	dir  string
}

func getbase(lat, lon float64) (int, int) {
	blat := math.Floor(lat)
	blon := math.Floor(lon)
	return int(blat), int(blon)
}
func iabs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func get_file_name(lat, lon float64) (string, int, int) {
	blat, blon := getbase(lat, lon)
	ablat := iabs(blat)
	ablon := iabs(blon)

	var latc byte
	var lonc byte
	if lat > 0.0 {
		latc = 'N'
	} else {
		latc = 'S'
	}
	if lon > 0.0 {
		lonc = 'E'
	} else {
		lonc = 'W'
	}
	return fmt.Sprintf("%c%02d%c%03d.hgt", latc, ablat, lonc, ablon), blat, blon
}

func (h *hgtDb) newHgt(lat, lon float64) (hh *hgtHandle, err error) {
	hh = &hgtHandle{}
	hh.fname, hh.blat, hh.blon = get_file_name(lat, lon)
	fname := filepath.Join(h.dir, hh.fname)
	hh.fp, err = os.Open(fname)
	if err == nil {
		var f os.FileInfo
		f, err = hh.fp.Stat()
		if err == nil {
			ss := f.Size() / 2
			if ss/1201 == 1201 {
				hh.width = 1201
				hh.arc = 3
			} else if ss/3601 == 3601 {
				hh.width = 3601
				hh.arc = 1
			}
		}
	}
	return hh, err
}

func (hh *hgtHandle) readpt(y, x int) (hgt int16) {
	var pos int64
	b := make([]byte, 2)
	hgt = 0
	row := hh.width - 1 - y
	pos = int64(2 * (row*hh.width + x))
	_, err := hh.fp.ReadAt(b, pos)

	if err == nil {
		hgt = int16(b[0])<<8 | int16(b[1])
	}
	return hgt
}

func (hh *hgtHandle) get_elevation(lat, lon float64) float64 {
	if hh.fp != nil {
		dslat := 3600.0 * (lat - float64(hh.blat))
		dslon := 3600.0 * (lon - float64(hh.blon))
		y := int(dslat) / hh.arc
		x := int(dslon) / hh.arc
		var elevs [4]int16
		elevs[0] = hh.readpt(y+1, x)
		elevs[1] = hh.readpt(y+1, x+1)
		elevs[2] = hh.readpt(y, x)
		elevs[3] = hh.readpt(y, x+1)

		dy := math.Mod(dslat, float64(hh.arc)) / float64(hh.arc)
		dx := math.Mod(dslon, float64(hh.arc)) / float64(hh.arc)

		var e = float64(elevs[0])*dy*(1-dx) +
			float64(elevs[1])*dy*(dx) +
			float64(elevs[2])*(1-dy)*(1-dx) +
			float64(elevs[3])*(1-dy)*dx
		return e
	} else {
		return DEM_NODATA
	}
}

func NewHgtDb(dir string) *hgtDb {
	if dir == "" {
		def := os.Getenv("HOME")
		dir = filepath.Join(def, ".cache", "mwp", "DEMs")
	}
	return &hgtDb{dir: dir}
}

func (h *hgtDb) Close() {
	for _, hh := range h.hgts {
		hh.fp.Close()
	}
}

func (h *hgtDb) findHgt(lat, lon float64) (*hgtHandle, bool) {
	blat, blon := getbase(lat, lon)
	for _, hh := range h.hgts {
		if hh.blat == blat && hh.blon == blon {
			return hh, true
		}
	}
	return nil, false
}

func (h *hgtDb) lookup(lat, lon float64) float64 {
	hh, ok := h.findHgt(lat, lon)
	if !ok {
		var err error
		hh, err = h.newHgt(lat, lon)
		if err == nil {
			h.hgts = append(h.hgts, hh)
		} else {
			return DEM_NODATA
		}
	}
	return hh.get_elevation(lat, lon)
}
