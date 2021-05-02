package main

import (
	"os"
	"strings"
	"strconv"
	"bufio"
	"path/filepath"
)

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
							Conf.homepos = p1
						case "rth-alt":
							Conf.rthalt, _ = strconv.Atoi(p1)
						case "margin":
							Conf.margin, _ = strconv.Atoi(p1)
						case "sanity":
							Conf.sanity, _ = strconv.Atoi(p1)
						}
					}
				}
			}
		}
	}
}
