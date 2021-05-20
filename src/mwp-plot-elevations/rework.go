package main

import (
	"math"
)

type mindex struct {
	midx    int
	pregnd  int
	postgnd int
}

func Rework(mpts []Point, gnd []int) {
	d := 0.0
	nmp := len(mpts)
	mr := mpts[nmp-1].D
	np := len(gnd)
	ddif := mr / float64(np)
	idx := 0
	mlist := []mindex{}

	for n, _ := range gnd {
		d += ddif
		if math.Round(mpts[idx].D) <= math.Round(d) {
			mx := mindex{}
			mx.midx = idx
			if idx == 0 {
				mx.pregnd = 0
				mx.postgnd = 0
			} else {
				mx.pregnd = n - 1
				mx.postgnd = n
			}
			mlist = append(mlist, mx)
			idx += 1
			if idx == nmp {
				break
			}
		}
	}
	for n, m := range mlist {
		if n == 0 || n == len(mlist)-1 {
			continue
		}
		wpdist := mpts[n+1].D - mpts[n].D
		astart := mpts[n].Xz
		wpadelta := mpts[n+1].Xz - astart
		ldiff := 0.0
		adj := 0.0
		for j := m.postgnd; j < mlist[n+1].pregnd; j++ {
			ax := float64(astart) + float64(wpadelta)*ldiff/wpdist
			adif := float64(Conf.Margin+gnd[j]) - ax
			if adif > adj {
				adj = adif
			}
			ldiff += ddif
		}
		if adj != 0.0 {
			mpts[n].Xz += int(math.Ceil(adj))
			mpts[n].Set = WP_UPDATED
			if mpts[n+1].Set != WP_RTH {
				mpts[n+1].Xz += int(math.Ceil(adj))
				mpts[n+1].Set = WP_UPDATED
			}
		}
	}
}
