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
	"encoding/binary"
	"encoding/xml"
	gpx "github.com/twpayne/go-gpx"
	"regexp"
)


const (
	OTX_none = iota
	OTX_dump
	OTX_stream
	OTX_gpx
)

type OTX struct {
	s       *MSPSerial
	gpxfile string
	mode    int
	verbose bool
	armed   bool
}

type otxrec struct {
	ts      time.Time
	lat     float64
	lon     float64
	alt     float64
	nsats   uint8
	pitch   int16
	roll    int16
	heading int16
	mvbat   uint16
	mah     uint16
	hdop    uint16
	rssi    uint8
	speed   uint8
	aspeed  uint8
	status  uint8
	fix     uint8
	crsf    bool
}

type ltmbuf struct {
	msg []byte
	len byte
}

func newLTM(mtype byte) *ltmbuf {
	paylen := byte(0)
	switch mtype {
	case 'A':
		paylen = 6
	case 'G':
		paylen = 14
	case 'N':
		paylen = 6
	case 'O':
		paylen = 14
	case 'S':
		paylen = 7
	case 'X':
		paylen = 6
	case 'x':
		paylen = 1
	}

	buf := make([]byte, paylen+4)
	buf[0] = '$'
	buf[1] = 'T'
	buf[2] = mtype
	ltm := &ltmbuf{buf, paylen}
	return ltm
}

func (l *ltmbuf) String() string {
	var sb strings.Builder
	for _, s := range l.msg {
		fmt.Fprintf(&sb, "%02x ", s)
	}
	return strings.TrimSpace(sb.String())
}
func (l *ltmbuf) checksum() {
	c := byte(0)
	for _, s := range l.msg[3:] {
		c = c ^ s
	}
	l.msg[l.len+3] = c
}

func (l *ltmbuf) aframe(b otxrec) {
	binary.LittleEndian.PutUint16(l.msg[3:5], uint16(b.pitch))
	binary.LittleEndian.PutUint16(l.msg[5:7], uint16(b.roll))
	binary.LittleEndian.PutUint16(l.msg[7:9], uint16(b.heading))
	l.checksum()
}

func (l *ltmbuf) gframe(b otxrec) {
	lat := int32(b.lat * 1.0e7)
	lon := int32(b.lon * 1.0e7)
	alt := int32(b.alt * 100)
	binary.LittleEndian.PutUint32(l.msg[3:7], uint32(lat))
	binary.LittleEndian.PutUint32(l.msg[7:11], uint32(lon))
	l.msg[11] = b.speed
	binary.LittleEndian.PutUint32(l.msg[12:16], uint32(alt))
	l.msg[16] = b.fix | (b.nsats << 2)
	l.checksum()
}

func (l *ltmbuf) oframe(b otxrec, hlat float64, hlon float64) {
	lat := int32(hlat * 1.0e7)
	lon := int32(hlon * 1.0e7)
	binary.LittleEndian.PutUint32(l.msg[3:7], uint32(lat))
	binary.LittleEndian.PutUint32(l.msg[7:11], uint32(lon))
	binary.LittleEndian.PutUint32(l.msg[11:15], 0)
	l.msg[15] = 1
	l.msg[16] = b.fix
	l.checksum()
}

func (l *ltmbuf) sframe(b otxrec) {
	binary.LittleEndian.PutUint16(l.msg[3:5], b.mvbat)
	binary.LittleEndian.PutUint16(l.msg[5:7], b.mah)
	l.msg[7] = b.rssi
	l.msg[8] = b.aspeed
	l.msg[9] = b.status
	l.checksum()
}

func (l *ltmbuf) xframe(b otxrec, xcount uint8) {
	binary.LittleEndian.PutUint16(l.msg[3:5], b.hdop)
	l.msg[5] = 0
	l.msg[6] = xcount
	l.msg[7] = 0
	l.checksum()
}

func (l *ltmbuf) lxframe() {
	l.msg[3] = 0
	l.checksum()
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

func dump_headers() {
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

func get_otx_line(r []string) otxrec {
	b := otxrec{}

	if s, _, ok := get_rec_value(r, "Tmp2"); ok {
		tmp2, _ := strconv.ParseInt(s, 10, 16)
		b.nsats = uint8(tmp2 % 100)
		gfix := tmp2 / 1000
		if (gfix & 1) == 1 {
			b.fix = 3
		} else if b.nsats > 0 {
			b.fix = 1
		} else {
			b.fix = 0
		}
		hdp := uint16((tmp2 % 1000) / 100)
		b.hdop = uint16(550 - (hdp * 50))
	}

	if s, _, ok := get_rec_value(r, "GPS"); ok {
		lstr := strings.Split(s, " ")
		if len(lstr) == 2 {
			b.lat, _ = strconv.ParseFloat(lstr[0], 64)
			b.lon, _ = strconv.ParseFloat(lstr[1], 64)
		}
	}

	if s, _, ok := get_rec_value(r, "Date"); ok {
		if s1, _, ok := get_rec_value(r, "Time"); ok {
			var sb strings.Builder
			sb.WriteString(s)
			sb.WriteByte(' ')
			sb.WriteString(s1)
			b.ts, _ = time.Parse("2006-01-02 15:04:05.000", sb.String())
		}
	}

	if s, u, ok := get_rec_value(r, "Alt"); ok {
		b.alt, _ = strconv.ParseFloat(s, 64)
		if u == "ft" {
			b.alt = b.alt * 0.3048
		}
	}

	if s, units, ok := get_rec_value(r, "GSpd"); ok {
		spd, _ := strconv.ParseFloat(s, 64)
		spd = normalise_speed(spd, units)
		if spd > 255 || spd < 0 {
			spd = 0
		}
		b.speed = uint8(spd)
		b.aspeed = b.speed
	}

	if s, units, ok := get_rec_value(r, "VSpd"); ok {
		spd, _ := strconv.ParseFloat(s, 64)
		spd = normalise_speed(spd, units)
		if spd > 255 || spd < 0 {
			spd = 0
		}
		b.aspeed = uint8(spd)
	}

	if s, _, ok := get_rec_value(r, "AccX"); ok {
		ax, _ := strconv.ParseFloat(s, 64)
		if s, _, ok := get_rec_value(r, "AccY"); ok {
			ay, _ := strconv.ParseFloat(s, 64)
			if s, _, ok = get_rec_value(r, "AccZ"); ok {
				az, _ := strconv.ParseFloat(s, 64)
				b.pitch, b.roll = acc_to_ah(ax, ay, az)
			}
		}
	}

	if s, _, ok := get_rec_value(r, "Hdg"); ok {
		v, _ := strconv.ParseFloat(s, 64)
		b.heading = int16(v)
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

		b.status = armed | failsafe | (ltmflags << 2)
	}

	if s, _, ok := get_rec_value(r, "VFAS"); ok {
		v, _ := strconv.ParseFloat(s, 64)
		b.mvbat = uint16(v * 1000)
	}

	if s, _, ok := get_rec_value(r, "RSSI"); ok {
		rssi, _ := strconv.ParseInt(s, 10, 32)
		rssi = rssi * 255 / 100
		b.rssi = uint8(rssi)
	}

	if s, u, ok := get_rec_value(r, "Fuel"); ok {
		if u == "mAh" {
			a, _ := strconv.ParseFloat(s, 64)
			b.mah = uint16(a)
		}
	}

	// Crossfire
	if s, _, ok := get_rec_value(r, "1RSS"); ok {
		rssi, _ := strconv.ParseInt(s, 10, 32)
		rssi = rssi * 255 / 100
		b.rssi = uint8(rssi)
		b.crsf = true

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
			b.status = 0
			if ltmmode > 4 {
				b.status = 1
			}
			b.status |= (fs | (ltmmode << 2))
		}
		if s, _, ok := get_rec_value(r, "Sats"); ok {
			ns, _ := strconv.ParseInt(s, 10, 16)
			b.nsats = uint8(ns)
			if ns > 5 {
				b.fix = 3
				b.hdop = uint16((3.3 - float64(ns)/12.0) * 100)
				if b.hdop < 50 {
					b.hdop = 50
				}
				if b.alt > 1 {
					b.status |= 1
				}
			} else if ns > 0 {
				b.fix = 1
				b.hdop = 800
			} else {
				b.fix = 0
				b.hdop = 999
			}
		}
		if s, _, ok := get_rec_value(r, "Ptch"); ok {
			v1, _ := strconv.ParseFloat(s, 64)
			b.pitch = int16(to_degrees(v1))
		}
		if s, _, ok := get_rec_value(r, "Roll"); ok {
			v1, _ := strconv.ParseFloat(s, 64)
			b.roll = int16(to_degrees(v1))
		}
		if s, _, ok := get_rec_value(r, "Yaw"); ok {
			v1, _ := strconv.ParseFloat(s, 64)
			b.heading = int16(to_degrees(v1))
		}
		if s, u, ok := get_rec_value(r, "RxBt"); ok {
			if u == "V" {
				v, _ := strconv.ParseFloat(s, 64)
				b.mvbat = uint16(v * 1000)
			}
		}
		if s, u, ok := get_rec_value(r, "Capa"); ok {
			if u == "mAh" {
				a, _ := strconv.ParseFloat(s, 64)
				b.mah = uint16(a)
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

func calc_speed(b otxrec, tdiff time.Duration, llat, llon float64) uint8 {
	spd := uint8(0)
	if tdiff > 0 && llat != 0 && llon != 0 {
		// Flat earth
		x := math.Abs(to_radians(b.lon-llon) * math.Cos(to_radians(b.lat)))
		y := math.Abs(to_radians(b.lat - llat))
		d := math.Sqrt(x*x+y*y) * 6371009.0
		spd = uint8(d / tdiff.Seconds())
	}
	return spd
}

func openStdoutOrFile(path string) (io.WriteCloser, error) {
	var err error
	var w io.WriteCloser

	if len(path) == 0 || path == "-" {
		w = os.Stdout
	} else {
		w, err = os.Create(path)
	}
	return w, err
}

func NewOTX() *OTX {
	return &OTX{}
}

func (o *OTX) Set_dump() {
	o.mode = OTX_dump
}

func (o *OTX) Gpx_init(fn string) {
	o.mode = OTX_gpx
	o.gpxfile = fn
}

func (o *OTX) Stream_init(s *MSPSerial) {
	o.mode = OTX_stream
	o.s = s
}

func (o *OTX) Verbose(v bool) {
	o.verbose = v
}

func (o *OTX) Armed(v bool) {
	o.armed = v
}

func (o *OTX) Reader(otxfile string, fast bool) {
	hlat := float64(0)
	hlon := float64(0)
	llat := float64(0)
	llon := float64(0)
	xcount := uint8(0)
	var wp []*gpx.WptType

	fh, err := os.Open(otxfile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "log file %s\n", err)
		os.Exit(-1)
	}
	defer fh.Close()

	r := csv.NewReader(fh)
	r.TrimLeadingSpace = true

	var lt, st time.Time

	for i := 0; ; i++ {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if i == 0 {
			read_headers(record)
			if o.mode == OTX_dump {
				dump_headers()
				return
			}
		} else {
			b := get_otx_line(record)
			if o.armed && ((b.status & 1) == 0) {
				continue
			}

			if st.IsZero() {
				st = b.ts
				lt = st
			}
			if hlat == 0 {
				if b.fix > 1 && b.nsats > 5 {
					hlat = b.lat
					hlon = b.lon
				}
			}

			if o.mode == OTX_stream {
				tdiff := b.ts.Sub(lt)
				if b.crsf {
					b.speed = calc_speed(b, tdiff, llat, llon)
					llat = b.lat
					llon = b.lon
				}

				l := newLTM('G')
				l.gframe(b)
				o.s.Write(l.msg)
				if o.verbose {
					fmt.Fprintf(os.Stderr, "Gframe : %s\n", l)
				}

				l = newLTM('A')
				l.aframe(b)
				o.s.Write(l.msg)
				if o.verbose {
					fmt.Fprintf(os.Stderr, "Aframe : %s\n", l)
				}

				l = newLTM('O')
				l.oframe(b, hlat, hlon)
				o.s.Write(l.msg)
				if o.verbose {
					fmt.Fprintf(os.Stderr, "Oframe : %s\n", l)
				}

				l = newLTM('S')
				l.sframe(b)
				o.s.Write(l.msg)
				if o.verbose {
					fmt.Fprintf(os.Stderr, "Sframe : %s\n", l)
				}

				l = newLTM('X')
				l.xframe(b, xcount)
				o.s.Write(l.msg)
				xcount = (xcount + 1) & 0xff
				if o.verbose {
					fmt.Fprintf(os.Stderr, "Xframe : %s\n", l)
				}

				if fast {
					time.Sleep(10 * time.Millisecond)
				} else if tdiff > 0 {
					time.Sleep(tdiff)
				}
			} else if o.mode == OTX_gpx {
				if b.nsats > 0 {
					w0 := gpx.WptType{Lat: b.lat,
						Lon:  b.lon,
						Ele:  b.alt,
						Time: b.ts,
						Name: fmt.Sprintf("WP%d", i)}
					wp = append(wp, &w0)
				}
			}
			lt = b.ts
		}
		if err != nil {
			fmt.Fprintf(os.Stderr, "reader %s\n", err)
			os.Exit(-1)
		}
	}
	if o.mode == OTX_stream {
		if o.s.Klass() == DevClass_FD {
			b := otxrec{}
			l := newLTM('X')
			l.xframe(b, xcount)
			o.s.Write(l.msg)
			l = newLTM('x')
			l.lxframe()
			o.s.Write(l.msg)
		}
		o.s.Close()
	} else if o.mode == OTX_gpx {
		gfh, err := openStdoutOrFile(o.gpxfile)
		if err == nil {
			g := &gpx.GPX{Version: "1.0", Creator: "otxreader",
				Trk: []*gpx.TrkType{&gpx.TrkType{TrkSeg: []*gpx.TrkSegType{&gpx.TrkSegType{TrkPt: wp}}}}}
			gfh.Write([]byte(xml.Header))
			g.WriteIndent(gfh, " ", " ")
			gfh.Write([]byte("\n"))
			gfh.Close()
		} else {
			fmt.Fprintf(os.Stderr, "gpx reader %s\n", err)
			os.Exit(-1)
		}
	}
}
