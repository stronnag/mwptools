package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const (
	WP_INIT = iota
	WP_HOME
	WP_RTH
	WP_UPDATED
)

type Point struct {
	X      float64 // longitude
	Y      float64 // latitude
	D      float64 // distance to here
	C      float64 // bearing to previous
	Gz     int     // ground amsl
	Mz     int     // above home
	Az     int     // WP AMSL
	Xz     int     // Adjusted
	Flag   int8    // P3
	Wpno   int8    // WP no
	Wpname string  //
	Set    uint8
}

type Options struct {
	Homepos string
	Svgfile string
	Output  string
	Rthalt  int
	Margin  int
	Sanity  int
	P3      int
	Noplot  bool
	Noalts  bool
	Upland  bool
	Dump    bool
	Keep    bool
}

func Dump_data(mpts []Point, fn string) {
	js, _ := json.Marshal(mpts)
	if fn == "" {
		fmt.Println(string(js))
	} else {
		fh, err := os.Create(fn)
		if err == nil {
			defer fh.Close()
			fh.Write(js)
		}
	}
}

func Dump_climb_dive(mpts []Point, tofs bool) {
	var fh *os.File
	var err error
	havefh := false
	if tofs {
		fn := filepath.Join(os.TempDir(), "mwpmission-angles.txt")
		fh, err = os.Create(fn)
		if err == nil {
			defer fh.Close()
			havefh = true
		}
	}
	lastd := 0.0
	lasta := 0
	altv := 0
	var lastp string
	var act string
	for _, m := range mpts {
		if m.D > 0 {
			ddif := m.D - lastd
			if Conf.Output == "" {
				altv = m.Az
			} else {
				altv = m.Xz
			}
			adif := altv - lasta
			if adif < 0 {
				act = "dive"
			} else {
				act = "climb"
			}
			angle := (180.0 / math.Pi) * math.Atan2(float64(adif), ddif)
			str := fmt.Sprintf("%4s - %4s\t%5.1f°\t(%s)\n", lastp, m.Wpname, angle, act)
			if havefh {
				fh.WriteString(str)
			}
			os.Stdout.WriteString(str)
		}
		lastd = m.D
		lasta = altv
		lastp = m.Wpname
	}
}

func Read_config() {
	cfile := ""
	hfiles := []string{".config/mwp/elev-plot", ".elev-plot.rc"}
	homed, err := os.UserHomeDir()
	if err == nil {
		if _, err = os.Stat(hfiles[1]); err == nil {
			cfile = hfiles[1]
		} else {
			for _, fn := range hfiles {
				fname := filepath.Join(homed, fn)
				if _, err = os.Stat(fname); err == nil {
					cfile = fname
					break
				}
			}
		}
		if cfile != "" {
			fh, err := os.Open(cfile)
			if err == nil {
				defer fh.Close()
				scanner := bufio.NewScanner(fh)
				for scanner.Scan() {
					line := scanner.Text()
					if len(line) < 8 || strings.HasPrefix(line, "#") {
						continue
					}
					parts := strings.Split(line, "=")
					if len(parts) == 2 {
						p0 := strings.TrimSpace(parts[0])
						p1 := strings.TrimSpace(parts[1])
						switch p0 {
						case "home":
							Conf.Homepos = p1
						case "rth-alt":
							Conf.Rthalt, _ = strconv.Atoi(p1)
						case "margin":
							Conf.Margin, _ = strconv.Atoi(p1)
						case "sanity":
							Conf.Sanity, _ = strconv.Atoi(p1)
						}
					}
				}
			}
		}
	}
}
