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

func Posit(lat1, lon1, cse, dist float64, rhumb bool) (float64, float64) {
	tc := to_radians(cse)
	rlat1 := to_radians(lat1)
	rdist := nm2r(dist)
	lat := 0.0
	lon := 0.0

	if rhumb {
		// Use Rhumb lines
		var q float64
		var dphi float64
		lat = rlat1 + rdist*math.Cos(tc)
		tmp := math.Tan(lat/2.0+math.Pi/4.0) / math.Tan(rlat1/2.0+math.Pi/4.0)
		if tmp <= 0 {
			tmp = 0.000000001
		}
		dphi = math.Log(tmp)
		if dphi == 0.0 || math.Abs(lat-rlat1) < 1.0e-6 {
			q = math.Cos(rlat1)
		} else {
			q = (lat - rlat1) / dphi
			dlon := rdist * math.Sin(tc) / q
			lon = math.Mod((to_radians(lon1)+dlon+math.Pi), (2*math.Pi)) - math.Pi
		}
	} else {
		lat = math.Asin(math.Sin(rlat1)*math.Cos(rdist) + math.Cos(rlat1)*math.Sin(rdist)*math.Cos(tc))
		dlon := math.Atan2(math.Sin(tc)*math.Sin(rdist)*math.Cos(rlat1), math.Cos(rdist)-math.Sin(rlat1)*math.Sin(lat))
		lon = math.Mod((math.Pi+to_radians(lon1)+dlon), (2*math.Pi)) - math.Pi
	}
	lat = to_degrees(lat)
	lon = to_degrees(lon)
	return lat, lon
}

/***********************8
import (
	"strconv"
	"os"
)

func main() {
	if len(os.Args) > 4 {
		la0, _ := strconv.ParseFloat(os.Args[1], 64)
		lo0, _ := strconv.ParseFloat(os.Args[2], 64)
		la1, _ := strconv.ParseFloat(os.Args[3], 64)
		lo1, _ := strconv.ParseFloat(os.Args[4], 64)
		c, d := Csedist(la0, lo0, la1, lo1)
		fmt.Printf("Bearing %.1f distance %fm (%fnm)\n", c, d*1852, d)
	} else {
		a, b := Posit(0, 50, 0, 60, false)
		fmt.Printf("%v %v\n", a, b)
		a, b = Posit(50, 0, 0, 60, false)
		fmt.Printf("%v %v\n", a, b)
		fmt.Println("Rhumb")
		a, b = Posit(0, 50, 0, 60, true)
		fmt.Printf("%v %v\n", a, b)
		a, b = Posit(50, 0, 0, 60, true)
		fmt.Printf("%v %v\n", a, b)
	}
}
*********************************/
