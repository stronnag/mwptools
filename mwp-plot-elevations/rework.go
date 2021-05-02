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
	mr := mpts[nmp-1].d
	np := len(gnd)
	ddif := mr / float64(np)
	idx := 0
	mlist := []mindex{}

	for n, _ := range gnd {
		d += ddif
		if math.Round(mpts[idx].d) <= math.Round(d) {
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
		wpdist := mpts[n+1].d - mpts[n].d
		astart := mpts[n].xz
		wpadelta := mpts[n+1].xz - astart
		ldiff := 0.0
		adj := 0.0
		for j := m.postgnd; j < mlist[n+1].pregnd; j++ {
			ax := float64(astart) + float64(wpadelta)*ldiff/wpdist
			adif := float64(Conf.margin+gnd[j]) - ax
			if adif > adj {
				adj = adif
			}
			ldiff += ddif
		}
		if adj != 0.0 {
			mpts[n].xz += int(math.Ceil(adj))
			mpts[n].set = WP_UPDATED
			if mpts[n+1].set != WP_RTH {
				mpts[n+1].xz += int(math.Ceil(adj))
				mpts[n+1].set = WP_UPDATED
			}
		}
	}
}
