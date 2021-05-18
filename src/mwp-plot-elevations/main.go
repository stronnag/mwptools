package main

import (
	"fmt"
	"strings"
	"flag"
	"strconv"
	"os"
	"log"
)

var (
	Conf  Options
	Homep Point
)

func parse_home() {
	parts := strings.Split(Conf.Homepos, " ")
	if len(parts) != 2 {
		parts = strings.Split(Conf.Homepos, ",")
	}
	if len(parts) == 2 {
		p0 := strings.Replace(parts[0], ",", ",", -1)
		p1 := strings.Replace(parts[1], ",", ",", -1)
		Homep.Y, _ = strconv.ParseFloat(p0, 64)
		Homep.X, _ = strconv.ParseFloat(p1, 64)
		Homep.Set = WP_HOME
	}
}

func main() {

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [options] missionfile\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
	}

	Read_config()

	flag.StringVar(&Conf.Homepos, "home", Conf.Homepos, "home as DD.dddd,DDD.dddd")
	flag.StringVar(&Conf.Svgfile, "plotfile", "", "SVG graph file")
	flag.StringVar(&Conf.Output, "output", "", "Revised mission file")
	flag.IntVar(&Conf.Rthalt, "rth-alt", Conf.Rthalt, "RTH altitude (m)")
	flag.IntVar(&Conf.P3, "force-alt", -1, "Force Altitude Mode (-1=from mission, 0=Relative, 1=Absolute")
	flag.IntVar(&Conf.Margin, "margin", Conf.Margin, "Clearance margin (m)")
	flag.BoolVar(&Conf.Noplot, "no-plot", false, "No interactive plot")
	flag.BoolVar(&Conf.Upland, "upland", false, "Update landing elevation offset")
	flag.BoolVar(&Conf.Noalts, "no-mission-alts", false, "Ignore extant mission altitudes")
	flag.BoolVar(&Conf.Dump, "dump", false, "Dump  internal data,exit")

	flag.Parse()
	parse_home()
	files := flag.Args()
	if len(files) < 1 {
		log.Fatal("need mission")
	}

	var mpts []Point

	m, err := NewMission(files[0])
	if err == nil {
		mpts = m.Get_points()
	} else {
		log.Fatal(err)
	}
	elev, err := Get_elevations(mpts, 0)
	if err == nil {
		m.Update_details(mpts, elev)
		if Conf.Dump {
			Dump_data(mpts)
			os.Exit(0)
		}
		npts := int(mpts[len(mpts)-1].D) / 30
		if npts > 1024 {
			npts = 1024
		}
		telev, err := Get_elevations(mpts, npts)
		if err != nil {
			log.Fatal(err)
		}
		if Conf.Output != "" {
			Rework(mpts, telev)
			m.Save(mpts)
		}
		Gnuplot_mission(mpts, telev)
	}
}
