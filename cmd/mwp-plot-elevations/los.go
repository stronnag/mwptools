package main

import (
	"fmt"
	"os"
)

func CheckLOS(mpts []Point, gnd []int, margin int) (int, int) {
	res := 0
	xres := 0
	nat := -1
	mpts[0].Az += 1
	delev := mpts[1].Az - mpts[0].Az
	for n, v := range gnd {
		mgn := margin * n / (len(gnd) - 1)
		lose := mpts[0].Az + delev*n/(len(gnd)-1)
		dlt := v - mgn

		//
		if lose < dlt {
			res = 3
		}
		if res == 0 && mgn != 0 {
			dlt = v
			if lose < dlt {
				res = 2
			}
		}
		if res == 0 && mgn != 0 {
			dlt = v + mgn
			if lose < dlt {
				res = 1
			}
		}
		if res > xres {
			xres = res
			nat = n
			fmt.Fprintf(os.Stderr, "LOS %d at %d, melev = %d, telev = %d, dlt = %d   margin = %d\n",
				xres, n, lose, v, dlt, mgn)
		}
	}
	return xres, nat
}
