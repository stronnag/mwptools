package main

import (
	"fmt"
	"io"
	"os"
	"encoding/csv"
	"sort"
	"strconv"
	"strings"
	"time"
	"math"
	"regexp"
	"path/filepath"
	"errors"
)

const (
	Is_Valid = 1 << iota
	Has_Craft
	Has_Firmware
	Has_Disarm
	Has_Size
	Has_Start
)

const LOGTIMEPARSE = "2006-01-02 15:04:05.000"
const TIMEDATE = "2006-01-02 15:04:05"

type FlightMeta struct {
	Logname  string
	Date     time.Time
	Index    int
	Start    int
	End      int
	Flags    int
	Duration time.Duration
}

type OTXrec struct {
	Ts       time.Time
	Lat      float64
	Lon      float64
	Alt      float64
	Nsats    uint8
	Pitch    int16
	Roll     int16
	Heading  int16
	Mvbat    uint16
	Mah      uint16
	Hdop     uint16
	Rssi     uint8
	Speed    uint8
	Aspeed   uint8
	Status   uint8
	Fix      uint8
	Amps     float64
	Throttle int
	Crsf     bool
}

type OTXSegment struct {
	Hlat float64
	Hlon float64
	Recs []OTXrec
}

type hdrrec struct {
	i int
	u string
}

var hdrs map[string]hdrrec

func read_headers(r []string) {
	hdrs = make(map[string]hdrrec)
	rx := regexp.MustCompile(`(\w+)\(([A-Za-z/@]*)\)`)
	var k string
	var u string
	for i, s := range r {
		m := rx.FindAllStringSubmatch(s, -1)
		if len(m) > 0 {
			k = m[0][1]
			u = m[0][2]
		} else {
			k = s
			u = ""
		}
		hdrs[k] = hdrrec{i, u}
	}
}

type OTXLOG struct {
	Name  string
	Metas []FlightMeta
}

func NewOTX(name string) OTXLOG {
	var l OTXLOG
	l.Name = name
	l.Metas = nil
	return l
}

func (o *OTXLOG) Dump() {
	var s string
	n := map[int][]string{}
	var a []int
	for k, v := range hdrs {
		if v.u == "" {
			s = k
		} else {
			s = fmt.Sprintf("%s(%s)", k, v.u)
		}
		n[v.i] = append(n[v.i], s)
	}

	for k := range n {
		a = append(a, k)
	}
	sort.Sort(sort.IntSlice(a))
	for _, k := range a {
		for _, s := range n[k] {
			fmt.Printf("%3d: %s\n", k, s)
		}
	}
}

func get_rec_value(r []string, key string) (string, string, bool) {
	var s string
	v, ok := hdrs[key]
	if ok {
		s = r[v.i]
	}
	return s, v.u, ok
}

func acc_to_ah(ax, ay, az float64) (pitch int16, roll int16) {
	pitch = -int16((180.0 * math.Atan2(ax, math.Sqrt(ay*ay+az*az)) / math.Pi))
	roll = int16((180.0 * math.Atan2(ay, math.Sqrt(ax*ax+az*az)) / math.Pi))
	return pitch, roll
}

func normalise_speed(v float64, u string) float64 {
	switch u {
	case "kmh":
		v = v / 3.6
	case "mph":
		v = v * 0.44704
	case "kts":
		v = v * 0.51444444
	}
	return v
}

func get_otx_line(r []string) OTXrec {
	b := OTXrec{}

	if s, _, ok := get_rec_value(r, "Tmp2"); ok {
		tmp2, _ := strconv.ParseInt(s, 10, 16)
		b.Nsats = uint8(tmp2 % 100)
		gfix := tmp2 / 1000
		if (gfix & 1) == 1 {
			b.Fix = 3
		} else if b.Nsats > 0 {
			b.Fix = 1
		} else {
			b.Fix = 0
		}
		hdp := uint16((tmp2 % 1000) / 100)
		b.Hdop = uint16(550 - (hdp * 50))
	}

	if s, _, ok := get_rec_value(r, "GPS"); ok {
		lstr := strings.Split(s, " ")
		if len(lstr) == 2 {
			b.Lat, _ = strconv.ParseFloat(lstr[0], 64)
			b.Lon, _ = strconv.ParseFloat(lstr[1], 64)
		}
	}

	if s, _, ok := get_rec_value(r, "Date"); ok {
		if s1, _, ok := get_rec_value(r, "Time"); ok {
			var sb strings.Builder
			sb.WriteString(s)
			sb.WriteByte(' ')
			sb.WriteString(s1)
			b.Ts, _ = time.Parse(LOGTIMEPARSE, sb.String())
		}
	}

	if s, u, ok := get_rec_value(r, "Alt"); ok {
		b.Alt, _ = strconv.ParseFloat(s, 64)
		if u == "ft" {
			b.Alt *= 0.3048
		}
	}

	if s, units, ok := get_rec_value(r, "GSpd"); ok {
		spd, _ := strconv.ParseFloat(s, 64)
		spd = normalise_speed(spd, units)
		if spd > 255 || spd < 0 {
			spd = 0
		}
		b.Speed = uint8(spd)
		b.Aspeed = b.Speed
	}

	if s, units, ok := get_rec_value(r, "VSpd"); ok {
		spd, _ := strconv.ParseFloat(s, 64)
		spd = normalise_speed(spd, units)
		if spd > 255 || spd < 0 {
			spd = 0
		}
		b.Aspeed = uint8(spd)
	}

	if s, _, ok := get_rec_value(r, "AccX"); ok {
		ax, _ := strconv.ParseFloat(s, 64)
		if s, _, ok := get_rec_value(r, "AccY"); ok {
			ay, _ := strconv.ParseFloat(s, 64)
			if s, _, ok = get_rec_value(r, "AccZ"); ok {
				az, _ := strconv.ParseFloat(s, 64)
				b.Pitch, b.Roll = acc_to_ah(ax, ay, az)
			}
		}
	}

	if s, _, ok := get_rec_value(r, "Hdg"); ok {
		v, _ := strconv.ParseFloat(s, 64)
		b.Heading = int16(v)
	}

	if s, _, ok := get_rec_value(r, "Thr"); ok {
		v, _ := strconv.ParseInt(s, 10, 32)
		b.Throttle = int(v)
	}

	if s, _, ok := get_rec_value(r, "Tmp1"); ok {
		tmp1, _ := strconv.ParseInt(s, 10, 16)
		modeU := tmp1 % 10
		modeT := (tmp1 % 100) / 10
		modeH := (tmp1 % 1000) / 100
		modeK := (tmp1 % 10000) / 1000
		modeJ := tmp1 / 10000

		armed := uint8(0)
		if (modeU & 4) == 4 {
			armed = 1
		}

		ltmflags := uint8(0)
		switch modeT {
		case 0:
			ltmflags = 4 //Acro
		case 1:
			ltmflags = 2 // Angle
		case 2:
			ltmflags = 3 // Horizon
		case 4:
			ltmflags = 0 // Manual
		}

		if (modeH & 2) == 2 {
			ltmflags = 8 // Alt Hold
		}
		if (modeH & 4) == 4 {
			ltmflags = 9 // PH
		}

		if modeK == 1 {
			ltmflags = 13 // RTH
		} else if modeK == 2 {
			ltmflags = 10 // WP
		} else if modeK == 8 {
			ltmflags = 18 // Cruise
		}

		failsafe := uint8(0)
		if modeJ == 4 {
			failsafe = 2
		}

		b.Status = armed | failsafe | (ltmflags << 2)
	}

	if s, _, ok := get_rec_value(r, "VFAS"); ok {
		v, _ := strconv.ParseFloat(s, 64)
		b.Mvbat = uint16(v * 1000)
	}

	if s, _, ok := get_rec_value(r, "RSSI"); ok {
		rssi, _ := strconv.ParseInt(s, 10, 32)
		b.Rssi = uint8(rssi)
	}

	if s, u, ok := get_rec_value(r, "Fuel"); ok {
		if u == "mAh" {
			a, _ := strconv.ParseFloat(s, 64)
			b.Mah = uint16(a)
		}
	}
	if s, u, ok := get_rec_value(r, "Curr"); ok {
		b.Amps, _ = strconv.ParseFloat(s, 64)
		if u == "mA" {
			b.Amps /= 1000
		}
	}

	// Crossfire
	if s, _, ok := get_rec_value(r, "1RSS"); ok {
		rssi, _ := strconv.ParseInt(s, 10, 32)
		b.Rssi = uint8(rssi)
		b.Crsf = true

		if s, _, ok = get_rec_value(r, "FM"); ok {
			fm := s
			ltmmode := byte(0)
			fs := byte(0)
			armed := byte(1)
			switch fm {
			case "0", "OK", "WAIT", "!ERR":
				armed = 0
			case "ACRO", "AIR":
				ltmmode = 4
			case "ANGL", "STAB":
				ltmmode = 2
			case "HOR":
				ltmmode = 3
			case "MANU":
				ltmmode = 0
			case "AH":
				ltmmode = 8
			case "HOLD":
				ltmmode = 9
			case "CRS", "3CRS":
				ltmmode = 18
			case "WP":
				ltmmode = 10
			case "RTH":
				ltmmode = 13
			case "!FS!":
				fs = 2
			}
			if fm == "0" {
				if s, _, ok := get_rec_value(r, "Thr"); ok {
					thr, _ := strconv.ParseInt(s, 10, 32)
					if thr > -1024 {
						armed = 1
					}
					/**
										if armed == 0 {
											fmt.Fprintf(os.Stderr, "disarmed t=%v thr=%v sat=%v alt=%v\n",
												b.ts, thr, b.nsats, b.alt)
										}
					          **/
				}
			}
			b.Status = armed | fs | (ltmmode << 2)
		}
		if s, _, ok := get_rec_value(r, "Sats"); ok {
			ns, _ := strconv.ParseInt(s, 10, 16)
			b.Nsats = uint8(ns)
			if ns > 5 {
				b.Fix = 3
				b.Hdop = uint16((3.3 - float64(ns)/12.0) * 100)
				if b.Hdop < 50 {
					b.Hdop = 50
				}
			} else if ns > 0 {
				b.Fix = 1
				b.Hdop = 800
			} else {
				b.Fix = 0
				b.Hdop = 999
			}
		}

		if s, _, ok := get_rec_value(r, "Ptch"); ok {
			v1, _ := strconv.ParseFloat(s, 64)
			b.Pitch = int16(to_degrees(v1))
		}
		if s, _, ok := get_rec_value(r, "Roll"); ok {
			v1, _ := strconv.ParseFloat(s, 64)
			b.Roll = int16(to_degrees(v1))
		}
		if s, _, ok := get_rec_value(r, "Yaw"); ok {
			v1, _ := strconv.ParseFloat(s, 64)
			b.Heading = int16(to_degrees(v1))
		}
		if s, u, ok := get_rec_value(r, "RxBt"); ok {
			if u == "V" {
				v, _ := strconv.ParseFloat(s, 64)
				b.Mvbat = uint16(v * 1000)
			}
		}
		if s, u, ok := get_rec_value(r, "Capa"); ok {
			if u == "mAh" {
				a, _ := strconv.ParseFloat(s, 64)
				b.Mah = uint16(a)
			}
		}
	}
	return b
}

func to_degrees(rad float64) float64 {
	return (rad * 180.0 / math.Pi)
}

func to_radians(deg float64) float64 {
	return (deg * math.Pi / 180.0)
}

func (o *OTXLOG) GetMetas() ([]FlightMeta, error) {
	var metas []FlightMeta

	fh, err := os.Open(o.Name)
	if err != nil {
		fmt.Fprintf(os.Stderr, "log file %s\n", err)
		return metas, err
	}
	defer fh.Close()

	basefile := filepath.Base(o.Name)
	r := csv.NewReader(fh)
	r.TrimLeadingSpace = true

	var lasttm time.Time
	dindex := -1
	tindex := -1

	idx := 0
	for i := 1; ; i++ {
		record, err := r.Read()
		if err == io.EOF {
			metas[idx-1].End = (i - 1)
			metas[idx-1].Duration = lasttm.Sub(metas[idx-1].Date)
			break
		}
		if i == 1 {
			read_headers(record) // for future usage
			for j, s := range record {
				switch s {
				case "Date":
					dindex = j
				case "Time":
					tindex = j
				}
				if dindex != -1 && tindex != -1 {
					break
				}
			}
		} else {
			var sb strings.Builder
			sb.WriteString(record[dindex])
			sb.WriteByte(' ')
			sb.WriteString(record[tindex])
			t_utc, _ := time.Parse(LOGTIMEPARSE, sb.String())
			if t_utc.Sub(lasttm).Seconds() > (time.Duration(120) * time.Second).Seconds() {
				if idx > 0 {
					metas[idx-1].End = i - 1
					metas[idx-1].Duration = lasttm.Sub(metas[idx-1].Date)
				}
				idx += 1
				mt := FlightMeta{Logname: basefile, Date: t_utc, Index: idx, Start: i}
				metas = append(metas, mt)
			}
			lasttm = t_utc
		}
		if err != nil {
			fmt.Fprintf(os.Stderr, "reader %s\n", err)
			return metas, err
		}
	}

	for j, mx := range metas {
		if mx.End-mx.Start > 64 {
			metas[j].Flags = Has_Start | Is_Valid
		}
	}
	if len(metas) == 0 {
		err = errors.New("No records in OTX file")
	}
	return metas, err
}

func (o *OTXLOG) Reader(m FlightMeta) OTXSegment {

	seg := OTXSegment{}

	fh, err := os.Open(o.Name)
	if err != nil {
		fmt.Fprintf(os.Stderr, "log file %s\n", err)
		return seg
	}
	defer fh.Close()

	r := csv.NewReader(fh)
	r.TrimLeadingSpace = true

	for i := 1; ; i++ {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if i >= m.Start && i <= m.End {
			b := get_otx_line(record)
			if (b.Status & 1) == 0 {
				continue
			}
			if seg.Hlat == 0 {
				if b.Fix > 1 && b.Nsats > 5 {
					seg.Hlat = b.Lat
					seg.Hlon = b.Lon
				}
			}
			seg.Recs = append(seg.Recs, b)
		}
	}
	return seg
}
