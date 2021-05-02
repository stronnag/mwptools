package main

import (
	"fmt"
	"strings"
	"flag"
	"strconv"
	"os"
	"log"
)

const (
	WP_INIT = iota
	WP_HOME
	WP_RTH
	WP_UPDATED
)


type Point struct {
	x      float64 // longitude
	y      float64 // latitude
	d      float64 // distance
	gz     int     // ground amsl
	mz     int     // above home
	az     int     // WP AMSL
	xz     int     // Adjusted
	flag   int8    // P3
	wpno   int8    // WP no
	wpname string  //
	set    uint8
}

type Options struct {
	homepos string
	svgfile string
	output  string
	rthalt  int
	margin  int
	sanity  int
	noplot  bool
	noalts  bool
	dump    bool
}

var (
	Conf  Options
	Homep Point
)


func parse_home() {
	parts := strings.Split(Conf.homepos, " ")
	if len(parts) != 2 {
		parts = strings.Split(Conf.homepos, ",")
	}
	if len(parts) == 2 {
		p0 := strings.Replace(parts[0], ",", ",", -1)
		p1 := strings.Replace(parts[1], ",", ",", -1)
		Homep.y, _ = strconv.ParseFloat(p0, 64)
		Homep.x, _ = strconv.ParseFloat(p1, 64)
		Homep.set = WP_HOME
	}
}

func main() {
	var mpts []Point
	var npts int

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [options] missionfile\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
	}

	Read_config()

	flag.StringVar(&Conf.homepos, "home", Conf.homepos, "home as DD.dddd,DDD.dddd")
	flag.StringVar(&Conf.svgfile, "plotfile", "", "SVG graph file")
	flag.StringVar(&Conf.output, "output", "", "Revised mission file")
	flag.IntVar(&Conf.rthalt, "rth-alt", Conf.rthalt, "RTH altitude (m)")
	flag.IntVar(&Conf.margin, "margin", Conf.margin, "Clearance margin (m)")
	flag.BoolVar(&Conf.noplot, "no-plot", false, "No interactive plot")
	flag.BoolVar(&Conf.noalts, "no-mission-alts", false, "Ignore extant mission altitudes")
	flag.BoolVar(&Conf.dump, "dump", false, "Dump  internal data,exit")

	flag.Parse()
	parse_home()
	files := flag.Args()
	if len(files) < 1 {
		log.Fatal("need mission")
	}

	m, err := NewMission(files[0])
	if err == nil {
		mpts = m.Get_points()
		d := m.Get_distance()
		npts = int(d) / 30
	} else {
		log.Fatal(err)
	}
	elev, err := Get_elevations(mpts, 0)
	if err == nil {
		m.Update_details(mpts, elev)
		if Conf.dump {
			for _, p := range mpts {
				fmt.Printf("%+v\n", p)
			}
			os.Exit(0)
		}

		if npts > 1024 {
			npts = 1024
		}
		telev, err := Get_elevations(mpts, npts)
		if err != nil {
			log.Fatal(err)
		}
		if Conf.output != "" {
			Rework(mpts, telev)
			m.Save(mpts)
		}
		Gnuplot_mission(mpts, telev)
	}
}
