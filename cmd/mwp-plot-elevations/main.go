package main

import (
	"bufio"
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

	spt := false
	demdir := ""
	flag.BoolVar(&spt, "stdin", spt, "stdin point as DD.dddd,DDD.dddd,Alt")
	flag.StringVar(&demdir, "localdem", demdir, "local DEM dir")
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
	if len(files) < 1 && !spt {
		log.Fatal("need mission")
	}

	astr := os.Getenv("MWP_BING_KEY")
	dm := InitDem(demdir)
	if dm.dem.dir == "" && astr == "" {
		os.Exit(1)
	}

	var err error
	var m *Mission
	var mpts []Point
	if spt == false {
		m, err = NewMission(files[0], 1)
		if err == nil {
			mpts = m.Get_points()
			process_elevations(dm, mpts, m, false)
		} else {
			log.Fatal(err)
		}
	} else {
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			p := scanner.Text()
			p = strings.TrimSpace(p)
			sp := parse_point(p)
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
			//			fmt.Fprintf(os.Stderr, "DBG Process with data %s\n", p)
			process_elevations(dm, mpts, m, true)
		}
	}
	Dump_data(mpts, "/tmp/.mwpmission.json")
}

func process_elevations(dm *DEMMgr, mpts []Point, m *Mission, spt bool) {
	elev, err := dm.Get_elevations(mpts, 0)
	if err == nil {
		if len(mpts) != len(elev) {
			fmt.Fprintf(os.Stderr, "mission=%d, DEM=%d\n", len(mpts), len(elev))
			os.Exit(2)
		}

		m.Update_details(mpts, elev)
		if Conf.Dump {
			Dump_data(mpts, "")
			os.Exit(0)
		}

		npts := int(mpts[len(mpts)-1].D) / 30
		if dm.dem == nil {
			if npts > len(mpts)*20 {
				npts = len(mpts) * 20
			}
			if npts > 1024 {
				npts = 1024
			}
		}

		if npts < 4 {
			npts = 4
		}

		//		fmt.Fprintf(os.Stderr, "DBG ge %d %d\n", len(mpts), npts)
		telev, err := dm.Get_elevations(mpts, npts)

		if err != nil {
			log.Fatal(err)
		}
		if Conf.Output != "" {
			Rework(mpts, telev)
			m.Save(mpts)
		}

		los := 0
		nat := 0.0
		if spt {
			los, nat = CheckLOS(mpts, telev, Conf.Margin)
		}
		Gnuplot_mission(mpts, telev, spt, los)
		if !spt {
			Dump_climb_dive(mpts, true)
		} else {
			fmt.Printf("%1d\t%7.5f\n", los, nat)
		}
	}
}
