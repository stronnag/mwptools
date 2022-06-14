package main

import (
	"fmt"
	"math"
	"os"
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
		jj := m.postgnd
		j0 := jj
		j1 := mlist[n+1].pregnd
		for j := j0; j < j1; j++ {
			ax := float64(astart) + float64(wpadelta)*ldiff/wpdist
			adif := float64(Conf.Margin+gnd[j]) - ax
			if adif > adj {
				adj = adif
				jj = j
			}
			ldiff += ddif
		}
		if adj != 0.0 {
			mpts[n].Xz += int(math.Ceil(adj))
			mpts[n].Set = WP_UPDATED
			if mpts[n+1].Set != WP_RTH {
				mpts[n+1].Xz += int(math.Ceil(adj))
				mpts[n+1].Set = WP_UPDATED
			} else {
				// Adjust pre RTH for proportional diff less Margin (we already have margin at RTH)
				xadj := int(math.Ceil(adj)*(1.0-float64((jj-j0))/float64((j1-j0)))) - Conf.Margin
				mpts[n].Xz += xadj
				if mpts[n].Xz < mpts[n].Gz+Conf.Margin {
					mpts[n].Xz = mpts[n].Gz + Conf.Margin
				}
				mpts[n].Set = WP_UPDATED
				fmt.Fprintf(os.Stderr, "WP %d adj %d mz = %d, az = %d, xz = %d, gz=%d Set %d\n",
					n, xadj, mpts[n].Mz, mpts[n].Az, mpts[n].Xz, mpts[n].Gz, mpts[n].Set)
			}
		} else {
			mpts[n].Set = WP_UPDATED
		}

	}
}
