package main

import (
	"os"
	"fmt"
	"strings"
	"bytes"
	"encoding/xml"
	"io/ioutil"
	"errors"
	"time"
	geo "github.com/stronnag/bbl2kml/pkg/geo"
)

type MissionMWP struct {
	Zoom      int     `xml:"zoom,attr"`
	Cx        float64 `xml:"cx,attr"`
	Cy        float64 `xml:"cy,attr"`
	Generator string  `xml:"generator,attr"`
	Stamp     string  `xml:"save-date,attr"`
}

type MissionItem struct {
	No     int     `xml:"no,attr"`
	Action string  `xml:"action,attr"`
	Lat    float64 `xml:"lat,attr"`
	Lon    float64 `xml:"lon,attr"`
	Alt    int32   `xml:"alt,attr"`
	P1     int16   `xml:"parameter1,attr"`
	P2     int16   `xml:"parameter2,attr"`
	P3     int16   `xml:"parameter3,attr"`
}

type Mvers struct {
	Value string `xml:"value,attr"`
}

type Mission struct {
	XMLName      xml.Name      `xml:"mission"`
	Version      Mvers         `xml:"version"`
	MwpMeta      MissionMWP    `xml:"mwp"̀`
	MissionItems []MissionItem `xml:"missionitem"̀`
}

var (
	needrth int
	dist    []float64
)

func NewMission(fname string) (*Mission, error) {
	var mission Mission
	r, err := os.Open(fname)
	if err == nil {
		defer r.Close()
		var dat []byte
		dat, err = ioutil.ReadAll(r)
		if bytes.Contains(dat, []byte("<MISSION")) {
			dat = fixup_case(dat)
		}
		if err == nil {
			err = xml.Unmarshal(dat, &mission)
			if err == nil {
				err = mission.check_for_home()
			}
		}
	}
	return &mission, err
}

func (m *Mission) Save(mpts []Point) {
	w, err := os.Create(Conf.output)
	if err == nil {
		defer w.Close()
		landno := int8(-1)
		m.Version.Value = "0.0-rc0"
		m.MwpMeta.Stamp = time.Now().UTC().Format(time.RFC3339)
		m.MwpMeta.Generator = "mwp-plot-elevations"
		for _, mi := range m.MissionItems {
			if mi.Action == "LAND" {
				landno = int8(mi.No)
				break
			}
		}

		for _, p := range mpts {
			if p.set == WP_UPDATED {
				midx := p.wpno - 1
				if m.MissionItems[midx].No != int(p.wpno) {
					panic("WPNo mismatched, doomed")
				}
				if m.MissionItems[midx].P3 == 0 {
					m.MissionItems[midx].Alt = int32(p.xz - mpts[0].gz)
				} else {
					m.MissionItems[midx].Alt = int32(p.xz)
				}
			}
			if Conf.upland && landno > 0 && p.wpno == landno {
				laltdiff := p.gz - mpts[0].gz
				fmt.Printf("LAND diff %d\n", laltdiff)
				m.MissionItems[landno-1].P2 = int16(laltdiff)
			}
		}
		out, _ := xml.MarshalIndent(m, " ", " ")
		fmt.Fprint(w, xml.Header)
		fmt.Fprintln(w, string(out))
	}
}

func (mi *MissionItem) Is_GeoPoint() bool {
	a := mi.Action
	return !(a == "RTH" || a == "SET_HEAD" || a == "JUMP")
}

func (m *Mission) check_for_home() error {
	ra := 0
	ngeo := 0
	var mlat, mlon float64
	for _, mi := range m.MissionItems {
		if mi.Is_GeoPoint() {
			if mlat == 0.0 && mlon == 0.0 {
				mlat = mi.Lat
				mlon = mi.Lon
			}
			ngeo += 1
			if mi.P3 == 0 {
				ra += 1
			}
		}
	}
	if ra > 0 && Homep.set != WP_HOME {
		return errors.New("No home and relative altitudes")
	}
	if ngeo == 0 {
		return errors.New("No geographic points found")
	}
	if Homep.set == WP_HOME && Conf.sanity != 0 {
		_, dm := geo.Csedist(Homep.y, Homep.x, mlat, mlon)
		if int(dm*1852) > Conf.sanity {
			return errors.New("Acceptable first WP distance exceeded")
		}
	}
	return nil
}

func (m *Mission) Get_distance() float64 {
	d := 0.0
	llat := Homep.y
	llon := Homep.x
	dist = append(dist, 0.0)
	for _, mi := range m.MissionItems {
		if mi.Is_GeoPoint() {
			if llat != 0.0 && llon != 0.0 {
				_, dm := geo.Csedist(llat, llon, mi.Lat, mi.Lon)
				d += dm * 1852.0
				dist = append(dist, d)
			}
			llat = mi.Lat
			llon = mi.Lon
		}
	}
	if needrth != 0 {
		_, dm := geo.Csedist(Homep.y, Homep.x, m.MissionItems[needrth].Lat, m.MissionItems[needrth].Lon)
		d += dm * 1852.0
		dist = append(dist, d)
	}
	return d
}

func (m *Mission) Get_points() []Point {
	mpts := []Point{}
	mnpts := len(m.MissionItems)
	if Homep.set == WP_HOME {
		if m.MissionItems[mnpts-1].Action == "RTH" {
			needrth = mnpts - 2
		}
		mpts = append(mpts, Homep)
	}
	for _, mi := range m.MissionItems {
		if mi.Is_GeoPoint() {
			mpts = append(mpts, Point{y: mi.Lat, x: mi.Lon})
		}
	}
	if needrth != 0 {
		mpts = append(mpts, Homep)
	}
	return mpts
}

func (m *Mission) Update_details(mpts []Point, elev []int) {
	n := 0
	if Homep.set == WP_HOME {
		mpts[0].wpno = 0
		mpts[0].wpname = "Home"
		mpts[0].gz = elev[0]
		mpts[0].mz = 0
		mpts[0].az = elev[0]
		mpts[0].xz = elev[0]
		mpts[0].flag = 0
		mpts[0].d = dist[0]
		mpts[0].set = WP_HOME
		n = 1
	}

	for _, mi := range m.MissionItems {
		if mi.Is_GeoPoint() {
			av := int(mi.Alt)

			mpts[n].wpno = int8(mi.No)
			mpts[n].wpname = fmt.Sprintf("WP%d", mi.No)
			mpts[n].gz = elev[n]
			mpts[n].flag = int8(mi.P3)
			mpts[n].d = dist[n]
			if mi.P3 == 0 {
				mpts[n].mz = av
				mpts[n].az = elev[0] + av
			} else {
				mpts[n].mz = av - elev[0]
				mpts[n].az = av
			}
			if Conf.noalts {
				mpts[n].xz = elev[n] + Conf.margin
			} else {
				mpts[n].xz = mpts[n].az
			}
			mpts[n].set = WP_INIT
			n += 1
		}
	}
	if needrth > 0 {
		mpts[n].wpno = -1
		mpts[n].wpname = "RTH"
		mpts[n].gz = elev[0]
		mpts[n].mz = Conf.rthalt
		mpts[n].az = elev[0] + Conf.rthalt
		mpts[n].xz = mpts[n].az
		mpts[n].flag = 0
		mpts[n].d = dist[n]
		mpts[n].set = WP_RTH
	}
}

func fixup_case(dat []byte) []byte {
	d := strings.Replace(string(dat), "MISSIONITEM", "missionitem", -1)
	d = strings.Replace(d, "MISSION", "mission", -1)
	return []byte(d)
}
