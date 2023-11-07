package main

import ()

func CheckLOS(mpts []Point, gnd []int) bool {
	delev := mpts[1].Az - mpts[0].Az
	for n, v := range gnd {
		lose := mpts[0].Az + delev*n/(len(gnd)-1)
		if lose < v {
			return false
		}
	}
	return true
}
