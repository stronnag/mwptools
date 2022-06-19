package main

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func getGnuplotCaps() int {
	ttypes := 0
	cmd := exec.Command("gnuplot", "-e", "set terminal")
	defer cmd.Wait()
	out, err := cmd.StdoutPipe()
	if err == nil {
		defer out.Close()
		err = cmd.Start()
		if err == nil {
			scanner := bufio.NewScanner(out)
			for scanner.Scan() {
				line := scanner.Text()
				if strings.Contains(line, "wxt ") {
					ttypes |= 1
				}
				if strings.Contains(line, "qt ") {
					ttypes |= 2
				}
			}
		}
	}
	return ttypes
}

func Gnuplot_mission(mpts []Point, gnd []int) {
	req := 0
	if Conf.Noplot == false {
		req |= 1
	}
	if Conf.Svgfile != "" {
		req |= 2
	}
	if req == 0 {
		return
	}
	np := len(mpts)
	mr := mpts[np-1].D
	np = len(gnd)
	ddif := mr / float64(np-1)
	minz := 99999

	tmpdir, err := ioutil.TempDir("", ".mplot")
	if os.Getenv("KEEP_TEMPS") == "" {
		defer os.RemoveAll(tmpdir)
	}
	if err != nil {
		log.Fatal(err)
	}

	ttypes := getGnuplotCaps()
	termstr := ""
	if (ttypes & 2) == 2 {
		termstr = "qt"
	} else if (ttypes & 1) == 1 {
		termstr = "wxt"
	} else {
		panic("No gnuplot / terminal")
	}

	d := 0.0
	tfname := filepath.Join(tmpdir, "terrain.csv")
	w, _ := os.Create(tfname)
	fmt.Fprintln(w, "Dist\tAMSL\tMargin")
	for _, g := range gnd {
		mgn := g + Conf.Margin
		fmt.Fprintf(w, "%.0f\t%d\t%d\n", d, g, mgn)
		d += ddif
		if g < minz {
			minz = g
		}
	}
	w.Close()

	mfname := filepath.Join(tmpdir, "mission.csv")
	w, _ = os.Create(mfname)
	fmt.Fprintln(w, "Dist\tMission")
	for _, p := range mpts {
		fmt.Fprintf(w, "%.0f\t%d\t%d\n", p.D, p.Az, p.Xz)
		if p.Az < minz {
			minz = p.Az
		}
	}
	w.Close()
	pfname := filepath.Join(tmpdir, "mwpmission.plt")
	w, _ = os.Create(pfname)
	w.WriteString(`#!/usr/bin/gnuplot -p
set bmargin 8
set key top right
set key box width +2
set grid
set termopt enhanced
set termopt font "sans,8"`)
	fmt.Fprintf(w, "\nset terminal %s size 960,400\n", termstr)
	w.WriteString(`set xtics font ", 7"
set xtics (`)
	for i, p := range mpts {
		if i != 0 {
			w.WriteString(",")
		}
		fmt.Fprintf(w, "%.0f", p.D)
	}
	w.WriteString(")\n")

	w.WriteString(`set xtics rotate by 45 offset -0.8,-1.5
set x2tics rotate by 60
set x2tics (`)
	for i, p := range mpts {
		if i != 0 {
			w.WriteString(",")
		}
		fmt.Fprintf(w, "\"%s\" %.0f", p.Wpname, p.D)
	}
	w.WriteString(")\n")
	w.WriteString(`set xlabel "Distance"
set bmargin 3
set offsets graph 0,0,0.01,0
set title "Mission Elevation"
set ylabel "Elevation"
show label
set xrange [ 0 : ]
set datafile separator "	"
#set style fill pattern 6 border lc rgb "#8FBC8F"

set yrange [ `)
	fmt.Fprintf(w, " %d : ]\n", minz)
	if req == 3 {
		w.WriteString("set terminal push\n")
	}
	if req&2 == 2 {
		fmt.Fprintf(w, "set terminal svg size 960 320 dynamic background rgb 'white' font 'sans,8' rounded\nset output \"%s\"\n", Conf.Svgfile)
	}
	fmt.Fprintf(w, "plot '%s' using 1:2 t \"Terrain\" w filledcurve y1=%d lt -1 lw 2  lc rgb \"#40a4cbb8\", '%s' using 1:2 t \"Mission\" w lines lt -1 lw 2  lc rgb \"red\"", tfname, minz, mfname)
	if Conf.Margin != 0 {
		fmt.Fprintf(w, ", '%s' using 1:3 t \"Margin %dm\" w lines lt -1 lw 2  lc rgb \"web-blue\"", tfname, Conf.Margin)
	}
	if Conf.Output != "" {
		fmt.Fprintf(w, ", '%s' using 1:3 t \"Adjust\" w lines lt -1 lw 2  lc rgb \"orange\"", mfname)
	}
	w.WriteString("\n")

	if req == 3 {
		fmt.Fprintln(w, `set terminal pop
set output
replot`)
	}
	w.Close()
	gp := exec.Command("gnuplot", "-p", pfname)
	err = gp.Run()
	if err != nil {
		log.Fatalf("gnuplot failed with %s\n", err)
	}
}
