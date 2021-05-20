package main

import (
	"os"
	"bufio"
	"strings"
	"strconv"
	"path"
	"io"
)

type BBLSummary struct {
	logname  string
	craft    string
	cdate    string
	firmware string
	fwdate   string
	disarm   string
	index    int
	size     int64
}

type reason int

func (r reason) String() string {
	var reasons = [...]string{"None", "Timeout", "Sticks", "Switch_3d", "Switch", "Killswitch", "Failsafe", "Navigation"}
	if r < 0 || int(r) >= len(reasons) {
		r = 0
	}
	return reasons[r]
}

func GetBBLMeta(fn string) ([]BBLSummary, error) {
	var bes []BBLSummary
	r, err := os.Open(fn)
	if err == nil {
		var nbes int
		var loffset int64

		base := path.Base(fn)
		scanner := bufio.NewScanner(r)

		zero_or_nl := func(data []byte, atEOF bool) (advance int, token []byte, err error) {
			if atEOF && len(data) == 0 {
				return 0, nil, nil
			}
			for i, b := range data {
				if b == '\n' || b == 0 || b == 0xff {
					return i + 1, data[0:i], nil
				}
			}

			if atEOF {
				return len(data), data, nil
			}
			return
		}

		scanner.Split(zero_or_nl)
		for scanner.Scan() {
			l := scanner.Text()
			switch {
			case strings.Contains(string(l), "H Product:"):
				offset, _ := r.Seek(0, io.SeekCurrent)

				if loffset != 0 {
					bes[nbes].size = offset - loffset
				}
				loffset = offset
				be := BBLSummary{disarm: "NONE", size: 0}
				bes = append(bes, be)
				nbes = len(bes) - 1
				bes[nbes].logname = base
				bes[nbes].index = nbes + 1

			case strings.HasPrefix(string(l), "H Firmware revision:"):
				if n := strings.Index(string(l), ":"); n != -1 {
					fw := string(l)[n+1:]
					bes[nbes].firmware = fw
				}

			case strings.HasPrefix(string(l), "H Firmware date:"):
				if n := strings.Index(string(l), ":"); n != -1 {
					fw := string(l)[n+1:]
					bes[nbes].fwdate = fw
				}

			case strings.HasPrefix(string(l), "H Log start datetime:"):
				if n := strings.Index(string(l), ":"); n != -1 {
					date := string(l)[n+1:]
					bes[nbes].cdate = date
				}

			case strings.HasPrefix(string(l), "H Craft name:"):
				if n := strings.Index(string(l), ":"); n != -1 {
					cname := string(l)[n+1:]
					bes[nbes].craft = cname
				}

			case strings.Contains(string(l), "reason:"):
				if n := strings.Index(string(l), ":"); n != -1 {
					dindx, _ := strconv.Atoi(string(l)[n+1 : n+2])
					bes[nbes].disarm = reason(dindx).String()
				}
			}
			if err = scanner.Err(); err != nil {
				return bes, err
			}
		}
		if bes[nbes].size == 0 {
			offset, _ := r.Seek(0, io.SeekCurrent)
			if loffset != 0 {
				bes[nbes].size = offset - loffset
			}
		}
	}
	return bes, err
}
