package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Point struct {
	lat float64
	lon float64
}

type GeoZone struct {
	zid    int
	shape  int
	gtype  int
	minalt int
	maxalt int
	action int
	points []Point
}

const (
	SHAPE_CIRCLE = 0
	SHAPE_POLY   = 1
)

const (
	TYPE_EXC = 0
	TYPE_INC = 1
)

func NewGeoZones(fn string) ([]GeoZone, error) {
	var gzone = make([]GeoZone, 0)
	r, err := os.Open(fn)
	if err == nil {
		defer r.Close()
		zid := -1
		scanner := bufio.NewScanner(r)
		for scanner.Scan() {
			l := scanner.Text()
			l = strings.TrimSpace(l)
			if !(len(l) == 0 || strings.HasPrefix(l, "#") || strings.HasPrefix(l, ";")) {
				parts := strings.Split(l, " ")
				/*
				   geozone <id> <shape> <type> <minimum altitude> <maximum altitude> <fence action>
				     0      1      2      3            4                 5                 6
				   geozone vertex <zone id> <vertex idx> <latitude> <logitude>
				     0       1      2            3           4          5
				*/
				if len(parts) > 5 {
					switch parts[1] {
					case "vertex":
						vid := -1
						ilat := -1
						ilon := -1
						zid, err = strconv.Atoi(parts[2])
						if err == nil {
							vid, err = strconv.Atoi(parts[3])
							if err == nil {
								if zid < len(gzone) && vid == len(gzone[zid].points) {
									ilat, err = strconv.Atoi(parts[4])
									if err == nil {
										ilon, err = strconv.Atoi(parts[5])
										if err == nil {
											if ilon == 0 {
												gzone[zid].points = append(gzone[zid].points, Point{float64(ilat) / 100.0, 0.0})
											} else {
												gzone[zid].points = append(gzone[zid].points, Point{float64(ilat) / 1e7, float64(ilon) / 1e7})
											}
										}
									}
								}
							}
						} else {
							fmt.Fprintf(os.Stderr, "Invalid vertex %d/%d\n", zid, vid)
						}
					default:
						zid, err = strconv.Atoi(parts[1])
						if zid == len(gzone) {
							var gz = GeoZone{}
							gz.zid = zid
							gz.shape, err = strconv.Atoi(parts[2])
							if err == nil {
								gz.gtype, err = strconv.Atoi(parts[3])
								if err == nil {
									gz.minalt, err = strconv.Atoi(parts[4])
									if err == nil {
										gz.maxalt, err = strconv.Atoi(parts[5])
										if err == nil {
											gz.action, err = strconv.Atoi(parts[6])
											gz.minalt /= 100
											gz.maxalt /= 100
											gzone = append(gzone, gz)
										}
									}
								}
							}
						} else {
							fmt.Fprintf(os.Stderr, "Invalid zone id %d\n", zid)
						}
					}
				}
			}
		}
	}
	return gzone, err
}
