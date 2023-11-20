package main

import (
	"math"
)

func nm2r(nm float64) float64 {
	return (math.Pi / (180.0 * 60.0)) * nm
}

func r2nm(r float64) float64 {
	return ((180.0 * 60.0) / math.Pi) * r
}

func to_radians(d float64) float64 {
	return d * (math.Pi / 180.0)
}

func to_degrees(r float64) float64 {
	return r * (180.0 / math.Pi)
}

func project_point(lat1, lon1, cse, dist float64) (float64, float64) {
	dist = dist / 1852.0
	tc := to_radians(cse)
	rlat1 := to_radians(lat1)
	rlon1 := to_radians(lon1)
	rdist := nm2r(dist)
	lat := 0.0
	lon := 0.0

	lat = math.Asin(math.Sin(rlat1)*math.Cos(rdist) + math.Cos(rlat1)*math.Sin(rdist)*math.Cos(tc))
	if math.Cos(lat) == 0.0 {
		lon = rlon1 // endpoint a pole
	} else {
		/*
		 * ** Note signed changed from Williams formulae, as we're going forward ... **
		 * We just use the worst case version because modern computers don't care
		 */
		dlon := math.Atan2(math.Sin(tc)*math.Sin(rdist)*math.Cos(rlat1), math.Cos(rdist)-math.Sin(rlat1)*math.Sin(lat))
		lon = math.Mod((math.Pi+rlon1+dlon), (2*math.Pi)) - math.Pi
	}
	lat = to_degrees(lat)
	lon = to_degrees(lon)
	return lat, lon
}
