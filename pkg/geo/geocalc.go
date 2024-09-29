package geo

import (
	"math"
)

const RAD2DEG float64 = (180.0 / math.Pi)
const DEG2RAD float64 = (math.Pi / 180.0)

func nm2r(nm float64) float64 {
	return (DEG2RAD / 60.0) * nm
}

func r2nm(r float64) float64 {
	return 60.0 * RAD2DEG * r
}

func to_radians(d float64) float64 {
	return d * DEG2RAD
}

func to_degrees(r float64) float64 {
	return r * RAD2DEG
}

func Csedist(_lat1, _lon1, _lat2, _lon2 float64) (float64, float64) {
	lat1 := to_radians(_lat1)
	lon1 := to_radians(_lon1)
	lat2 := to_radians(_lat2)
	lon2 := to_radians(_lon2)

	p1 := math.Sin((lat1 - lat2) / 2.0)
	p2 := math.Cos(lat1) * math.Cos(lat2)
	p3 := math.Sin((lon2 - lon1) / 2.0)
	d := 2.0 * math.Asin(math.Sqrt((p1*p1)+p2*(p3*p3)))
	d = r2nm(d)
	cse := math.Mod((math.Atan2(math.Sin(lon2-lon1)*math.Cos(lat2),
		math.Cos(lat1)*math.Sin(lat2)-math.Sin(lat1)*math.Cos(lat2)*math.Cos(lon2-lon1))),
		(2.0 * math.Pi))
	cse = to_degrees(cse)
	if cse < 0.0 {
		cse += 360
	}
	return cse, d
}

func Posit(lat1, lon1, cse, dist float64) (float64, float64) {
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
