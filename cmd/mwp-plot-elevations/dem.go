package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"math"
	"net/http"
	"os"
	"strings"
)

import (
	"geo"
)

type BingRes struct {
	ResourceSets []struct {
		Resources []struct {
			Elevations []int
			Zoomlevel  int
		}
	}
	Statuscode        int
	Statusdescription string
}

type DEMMgr struct {
	dem *hgtDb
}

const ENCSTR string = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
const KENC string = "QXFzVEFpcGFCQnBLTFhoY2FHZ1A4a2NlWXVrYXRtdERMUzF4MENYRWhSWm5wbDFSRUxGOWhsSThqNG1OSWtyRQ=="

func InitDem(demdir string) (d *DEMMgr) {
	d = &DEMMgr{}
	d.dem = NewHgtDb(demdir)
	return d
}

func pca(pts []Point) string {
	lat := int64(0)
	lon := int64(0)
	var sb strings.Builder

	for _, s := range pts {
		nlat := int64(math.Round(s.Y * 100000.0))
		nlon := int64(math.Round(s.X * 100000.0))
		dy := nlat - lat
		dx := nlon - lon
		lat = nlat
		lon = nlon

		dy = (dy << 1) ^ (dy >> 31)
		dx = (dx << 1) ^ (dx >> 31)
		index := ((dy + dx) * (dy + dx + 1) / 2) + dy
		rem := int64(0)
		for index > 0 {
			rem = index & 31
			index = (index - rem) / 32
			if index > 0 {
				rem += 32
			}
			sb.WriteByte(ENCSTR[rem])
		}
	}
	return sb.String()
}

func parse_response(js []byte) []int {
	var ev BingRes
	json.Unmarshal(js, &ev)
	return ev.ResourceSets[0].Resources[0].Elevations
}

func (d *DEMMgr) Get_elevations(p []Point, nsamp int) ([]int, error) {
	var elevs []int
	var err error
	if d.dem != nil {
		elevs, err = d.get_dem_elevations(p, nsamp)
	} else {
		elevs, err = get_bing_elevations(p, nsamp)
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

func get_bing_elevations(p []Point, nsamp int) ([]int, error) {
	var elev []int

	astr := os.Getenv("MWP_BING_KEY")
	if astr == "" {
		bs, _ := base64.StdEncoding.DecodeString(KENC)
		astr = string(bs)
	}
	var sb strings.Builder
	sb.WriteString("http://dev.virtualearth.net/REST/v1/Elevation/")
	if nsamp == 0 {
		sb.WriteString("List/")
	} else {
		sb.WriteString("Polyline/")
	}
	sb.WriteString("?key=")
	sb.WriteString(astr)
	if nsamp != 0 {
		sb.WriteString(fmt.Sprintf("&samp=%d", nsamp))
	}
	pstr := pca(p)
	pstr = fmt.Sprintf("points=%s", pstr)
	req, err := http.NewRequest("POST", sb.String(), bytes.NewBufferString(pstr))
	req.Header.Set("Accept", "*/*")
	req.Header.Set("Content-Type", "text/plain; charset=utf-8")
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(pstr)))

	client := &http.Client{}
	resp, err := client.Do(req)
	if err == nil {
		defer resp.Body.Close()
		body, err := ioutil.ReadAll(resp.Body)
		if err == nil && resp.StatusCode == 200 {
			elev = parse_response(body)
		}
	}
	return elev, err
}
