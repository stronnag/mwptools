package main

import (
	"os"
	"strings"
	"strconv"
	"bufio"
	"path/filepath"
	"fmt"
	"encoding/json"
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
	D      float64 // distance
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
}

func Dump_data(mpts []Point) {
	js, _ := json.Marshal(mpts)
	fmt.Println(string(js))
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
