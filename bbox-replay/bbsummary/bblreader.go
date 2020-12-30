package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"encoding/csv"
	"sort"
	"strconv"
)

type BBLStats struct {
	max_alt          float64
	max_alt_time     uint64
	max_range        float64
	max_range_time   uint64
	max_speed        float64
	max_speed_time   uint64
	max_current      float64
	max_current_time uint64
	distance         float64
	duration         uint64
}

type BBLRec struct {
	stamp  uint64
	lat    float64
	lon    float64
	alt    float64
	spd    float64
	amps   float64
	fix    uint8
	numsat uint8
}

var hdrs map[string]int

func get_rec_value(r []string, key string) (string, bool) {
	var s string
	i, ok := hdrs[key]
	if ok {
		if i < len(r) {
			s = r[i]
		} else {
			ok = false
		}
	}
	return s, ok
}
func get_bbl_line(r []string) BBLRec {
	b := BBLRec{}
	s, ok := get_rec_value(r, "amperage (A)")
	if ok {
		b.amps, _ = strconv.ParseFloat(s, 64)
	}
	s, ok = get_rec_value(r, "navPos[2]")
	if ok {
		b.alt, _ = strconv.ParseFloat(s, 64)
	}
	s, ok = get_rec_value(r, "GPS_fixType")
	if ok {
		i64, _ := strconv.Atoi(s)
		b.fix = uint8(i64)
	}
	s, ok = get_rec_value(r, "GPS_numSat")
	if ok {
		i64, _ := strconv.Atoi(s)
		b.numsat = uint8(i64)
	}
	s, ok = get_rec_value(r, "GPS_coord[0]")
	if ok {
		b.lat, _ = strconv.ParseFloat(s, 64)
	}
	s, ok = get_rec_value(r, "GPS_coord[1]")
	if ok {
		b.lon, _ = strconv.ParseFloat(s, 64)
	}
	s, ok = get_rec_value(r, "GPS_speed (m/s)")
	if ok {
		b.spd, _ = strconv.ParseFloat(s, 64)
	}
	s, ok = get_rec_value(r, "time (us)")
	if ok {
		i64, _ := strconv.ParseInt(s, 10, 64)
		b.stamp = uint64(i64)
	}
	return b
}

func get_headers(r []string) map[string]int {
	m := make(map[string]int)
	for i, s := range r {
		m[s] = i
	}
	return m
}

func dump_headers(m map[string]int) {
	n := map[int][]string{}
	var a []int
	for k, v := range m {
		n[v] = append(n[v], k)
	}
	for k := range n {
		a = append(a, k)
	}
	sort.Sort(sort.IntSlice(a))
	for _, k := range a {
		for _, s := range n[k] {
			fmt.Printf("%s, %d\n", s, k)
		}
	}
}

func bblreader(bbfile string, idx int, dump bool) {
	cmd := exec.Command("blackbox_decode", "--merge-gps", "--stdout", "--index",
		strconv.Itoa(idx), bbfile)
	out, err := cmd.StdoutPipe()
	defer cmd.Wait()
	defer out.Close()

	r := csv.NewReader(out)
	r.TrimLeadingSpace = true

	err = cmd.Start()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to start err=%v", err)
		os.Exit(1)
	}

	bblsmry := BBLStats{0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

	var home_lat, home_lon, llat, llon float64
	var dt, st, lt uint64

	have_origin := false

	for i := 0; ; i++ {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if i == 0 {
			hdrs = get_headers(record)
			if dump {
				dump_headers(hdrs)
				return
			}
		}

		br := get_bbl_line(record)
		if br.fix != 2 {
			continue
		}
		if !have_origin {
			if br.fix == 2 && br.numsat > 5 {
				have_origin = true
				home_lat = br.lat
				home_lon = br.lon
				llat = br.lat
				llon = br.lon
				st = br.stamp
			}
		} else {
			us := br.stamp

			// Do the expensive calc every 50ms
			if (us - dt) > 1000*50 {
				_, d := Csedist(home_lat, home_lon, br.lat, br.lon)
				if d > bblsmry.max_range {
					bblsmry.max_range = d
					bblsmry.max_range_time = us - st
				}

				if llat != br.lat && llon != br.lon {
					_, d := Csedist(llat, llon, br.lat, br.lon)
					bblsmry.distance += d
					llat = br.lat
					llon = br.lon
				}
				dt = us
			}

			if br.alt > bblsmry.max_alt {
				bblsmry.max_alt = br.alt
				bblsmry.max_alt_time = us - st
			}

			if br.spd > bblsmry.max_speed {
				bblsmry.max_speed = br.spd
				bblsmry.max_speed_time = us - st
			}

			if br.amps > bblsmry.max_current {
				bblsmry.max_current = br.amps
				bblsmry.max_current_time = us - st
			}
			lt = us
		}
		if err != nil {
			log.Fatal(err)
		}
	}
	bblsmry.duration = lt - st
	bblsmry.max_alt /= 100
	bblsmry.max_range *= 1852.0
	bblsmry.distance *= 1852.0
	fmt.Printf("Altitude : %.1f m at %s\n", bblsmry.max_alt, show_time(bblsmry.max_alt_time))
	fmt.Printf("Speed    : %.1f m/s at %s\n", bblsmry.max_speed, show_time(bblsmry.max_speed_time))
	fmt.Printf("Range    : %.0f m at %s\n", bblsmry.max_range, show_time(bblsmry.max_range_time))
	if bblsmry.max_current > 0 {
		fmt.Printf("Current  : %.1f A at %s\n", bblsmry.max_current, show_time(bblsmry.max_current_time))
	}
	fmt.Printf("Distance : %.0f m\n", bblsmry.distance)
	fmt.Printf("Duration : %s\n", show_time(bblsmry.duration))
}

func show_time(t uint64) string {
	secs := t / 1000000
	m := secs / 60
	s := secs % 60
	return fmt.Sprintf("%02d:%02d", m, s)
}
/**
func main() {
	bbfile := os.Args[1]
	dump := len(os.Args) > 2
	bblreader(bbfile, 1, dump)
}
**/
