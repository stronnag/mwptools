package main

import ()

func CheckLOS(mpts []Point, gnd []int, margin int) (int, float64) {
	res := 0
	xres := 0
	nat := 0.0
	mpts[0].Az += 1
	delev := mpts[1].Az - mpts[0].Az
	for n, v := range gnd {
		mgn := margin * n / (len(gnd) - 1)
		lose := mpts[0].Az + delev*n/(len(gnd)-1)
		dlt := v

		//
		if lose < dlt {
			res = 2
		} else {
			if mgn != 0 {
				dlt = v + mgn
				if lose < dlt {
					res = 1
				}
			}
		}
		if res > xres {
			xres = res
			nat = float64(n) / float64(len(gnd)-1)
		}
	}
	return xres, nat
}
