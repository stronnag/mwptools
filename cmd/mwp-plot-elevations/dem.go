package main

import (
	"fmt"
)

import (
	"geo"
)

type DEMMgr struct {
	dem *hgtDb
}

func InitDem(demdir string) (d *DEMMgr) {
	d = &DEMMgr{}
	d.dem = NewHgtDb(demdir)
	return d
}

func (d *DEMMgr) Get_elevations(p []Point, nsamp int) ([]int, error) {
	var elevs []int
	var err error
	if d.dem != nil {
		elevs, err = d.get_dem_elevations(p, nsamp)
	}
	return elevs, err
}

func (d *DEMMgr) lookup_and_check(lat, lon float64) (float64, error) {
	var e float64
	for j := 0; ; j++ {
		e = d.dem.lookup(lat, lon)
		if e == DEM_NODATA {
			if j == 0 {
				fname, _, _ := get_file_name(lat, lon)
				download(fname, d.dem.dir)
			} else {
				return e, fmt.Errorf("DEM: No data for %f %f", lat, lon)
				break
			}
		} else {
			break
		}
	}
	return e, nil
}

func (d *DEMMgr) get_dem_elevations(pts []Point, nsamp int) ([]int, error) {
	np := nsamp
	if np == 0 {
		np = len(pts)
	}

	elevs := make([]int, np)
	if nsamp == 0 {
		for i, p := range pts {
			e, err := d.lookup_and_check(p.Y, p.X)
			if err == nil {
				elevs[i] = int(e)
			} else {
				return nil, err
			}
		}
	} else {
		nmp := len(pts)
		maxr := pts[nmp-1].D
		e, err := d.lookup_and_check(pts[0].Y, pts[0].X)
		if err == nil {
			elevs[0] = int(e)
		} else {
			return nil, err
		}
		lastp := 0
		ep := 1
		for j := 1; j < nsamp-1; j++ {
			adist := maxr * float64(j) / float64(nsamp-1)
			for k := lastp; k < nmp; k++ {
				if adist < pts[k].D {
					lastp = k
					break
				}
			}
			if lastp != 0 {
				ddist := pts[lastp-1].D
				xdist := adist - ddist
				cse := pts[lastp].C
				nlat, nlon := geo.Posit(pts[lastp-1].Y, pts[lastp-1].X, cse, xdist/1852.0)
				ev := int(d.dem.lookup(nlat, nlon))
				elevs[ep] = int(ev)
				ep += 1
			}
		}
		elevs[ep] = int(d.dem.lookup(pts[nmp-1].Y, pts[nmp-1].X))
	}
	return elevs, nil
}
