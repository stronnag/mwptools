package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
)

var (
	Conf  Options
	Homep Point
)

func parse_point(hpos string) Point {
	var p Point
	p0 := ""
	p1 := ""
	parts := strings.Split(hpos, " ")
	if len(parts) != 2 {
		parts = strings.Split(hpos, ";")
	}
	if len(parts) != 2 {
		parts = strings.Split(hpos, ",")
	}
	if len(parts) == 2 || len(parts) == 3 {
		p0 = strings.Replace(parts[0], ",", ".", -1)
		p1 = strings.Replace(parts[1], ",", ".", -1)
	} else if len(parts) == 4 {
		p0 = strings.Join(parts[0:2], ".")
		p1 = strings.Join(parts[2:4], ".")
	}
	if p0 != "" && p1 != "" {
		p.Y, _ = strconv.ParseFloat(p0, 64)
		p.X, _ = strconv.ParseFloat(p1, 64)
	}
	if len(parts) == 3 {
		p.Mz, _ = strconv.Atoi(parts[2])
	}
	return p
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [options] missionfile\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
	}

	Read_config()

	spt := ""
	flag.StringVar(&spt, "single", spt, "point as DD.dddd,DDD.dddd,Alt")
	flag.StringVar(&Conf.Homepos, "home", Conf.Homepos, "home as DD.dddd,DDD.dddd")
	flag.StringVar(&Conf.Svgfile, "svg", "", "SVG graph file")
	flag.StringVar(&Conf.Output, "output", "", "Revised mission file")
	flag.IntVar(&Conf.Rthalt, "rth-alt", Conf.Rthalt, "RTH altitude (m)")
	flag.IntVar(&Conf.P3, "force-alt", -1, "Force Altitude Mode (-1=from mission, 0=Relative, 1=Absolute")
	flag.IntVar(&Conf.Margin, "margin", Conf.Margin, "Clearance margin (m)")
	flag.BoolVar(&Conf.Noplot, "no-graph", false, "No interactive plot")
	flag.BoolVar(&Conf.Upland, "upland", false, "Update landing elevation offset")
	flag.BoolVar(&Conf.Noalts, "no-mission-alts", false, "Ignore extant mission altitudes")
	flag.BoolVar(&Conf.Dump, "dump", false, "Dump  internal data, exit")
	flag.BoolVar(&Conf.Keep, "keep", false, "Keep intermediate plt files")

	flag.Parse()
	Homep = parse_point(Conf.Homepos)
	Homep.Set = WP_HOME
	files := flag.Args()
	if len(files) < 1 && spt == "" {
		log.Fatal("need mission")
	}

	var err error
	var m *Mission
	var mpts []Point
	if spt == "" {
		m, err = NewMission(files[0], 1)
		if err == nil {
			mpts = m.Get_points()
		} else {
			log.Fatal(err)
		}
	} else {
		sp := parse_point(spt)
		m = &Mission{}
		mis := []MissionItem{}
		var mi MissionItem
		mi.No = 1
		mi.Action = "WAYPOINT"
		mi.Lat = sp.Y
		mi.Lon = sp.X
		//		mi.D = 0
		mi.Alt = int32(sp.Mz)
		mi.Flag = 0xa5
		mis = append(mis, mi)
		m.MissionItems = mis
		mpts = m.Get_points()
		mpts[1].Wpname = "Query"
	}
	elev, err := Get_elevations(mpts, 0)
	if err == nil {
		if len(mpts) != len(elev) {
			fmt.Fprintf(os.Stderr, "mission=%d, bing=%d\n", len(mpts), len(elev))
			panic("Bing return size error")
		}

		m.Update_details(mpts, elev)
		if Conf.Dump {
			Dump_data(mpts, "")
			os.Exit(0)
		}

		npts := int(mpts[len(mpts)-1].D) / 30

		if npts > len(mpts)*20 {
			npts = len(mpts) * 20
		}

		if npts > 1024 {
			npts = 1024
		}

		//		fmt.Fprintf(os.Stderr, "Dist, npts %.3f %d\n", mpts[len(mpts)-1].D, npts)

		telev, err := Get_elevations(mpts, npts)
		if err != nil {
			log.Fatal(err)
		}
		if Conf.Output != "" {
			Rework(mpts, telev)
			m.Save(mpts)
		}

		los := 0
		if spt != "" {
			fmt.Fprintf(os.Stderr, "LOS Margin: %d\n", Conf.Margin)
			los, _ = CheckLOS(mpts, telev, Conf.Margin)
		}
		Gnuplot_mission(mpts, telev, (spt != ""), los)
		if spt == "" {
			Dump_climb_dive(mpts, true)
		} else {
			fmt.Printf("%d\n", los)
		}
	}
	Dump_data(mpts, "/tmp/.mwpmission.json")
}
