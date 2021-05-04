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
	w, err := os.Create(Conf.Output)
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
			if Conf.P3 != -1 && p.Flag != int8(Conf.P3) { // also update of changing alt mode
				p.Set = WP_UPDATED
			}
			if p.Set == WP_UPDATED {
				midx := p.Wpno - 1
				if m.MissionItems[midx].No != int(p.Wpno) {
					panic("WPNo mismatched, doomed")
				}
				if Conf.P3 != -1 {
					m.MissionItems[midx].P3 = int16(Conf.P3)
				}

				if m.MissionItems[midx].P3 == 0 {
					m.MissionItems[midx].Alt = int32(p.Xz - mpts[0].Gz)
				} else {
					m.MissionItems[midx].Alt = int32(p.Xz)
				}
			}
			if Conf.Upland && landno > 0 && p.Wpno == landno {
				laltdiff := p.Gz - mpts[0].Gz
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
	if ra > 0 && Homep.Set != WP_HOME {
		return errors.New("No home and relative altitudes")
	}
	if ngeo == 0 {
		return errors.New("No geographic points found")
	}
	if Homep.Set == WP_HOME && Conf.Sanity != 0 {
		_, dm := geo.Csedist(Homep.Y, Homep.X, mlat, mlon)
		if int(dm*1852) > Conf.Sanity {
			return errors.New("Acceptable first WP distance exceeded")
		}
	}
	return nil
}

func (m *Mission) Get_points() []Point {
	mpts := []Point{}
	mnpts := len(m.MissionItems)
	if Homep.Set == WP_HOME {
		if m.MissionItems[mnpts-1].Action == "RTH" {
			needrth = mnpts - 2
		}
		mpts = append(mpts, Homep)
	}
	for _, mi := range m.MissionItems {
		if mi.Is_GeoPoint() {
			mpts = append(mpts, Point{Y: mi.Lat, X: mi.Lon})
		}
	}
	if needrth != 0 {
		mpts = append(mpts, Homep)
	}
	return mpts
}

func (m *Mission) Update_details(mpts []Point, elev []int) {
	n := 0
	d := 0.0
	llat := Homep.Y
	llon := Homep.X

	if Homep.Set == WP_HOME {
		mpts[0].Wpno = 0
		mpts[0].Wpname = "Home"
		mpts[0].Gz = elev[0]
		mpts[0].Mz = 0
		mpts[0].Az = elev[0]
		mpts[0].Xz = elev[0]
		mpts[0].Flag = 0
		mpts[0].D = 0
		mpts[0].Set = WP_HOME
		n = 1
	}

	for _, mi := range m.MissionItems {
		if mi.Is_GeoPoint() {
			av := int(mi.Alt)
			mpts[n].Wpno = int8(mi.No)
			mpts[n].Wpname = fmt.Sprintf("WP%d", mi.No)
			mpts[n].Gz = elev[n]
			mpts[n].Flag = int8(mi.P3)
			if mi.P3 == 0 {
				mpts[n].Mz = av
				mpts[n].Az = elev[0] + av
			} else {
				mpts[n].Mz = av - elev[0]
				mpts[n].Az = av
			}
			if Conf.Noalts {
				mpts[n].Xz = elev[n] + Conf.Margin
			} else {
				mpts[n].Xz = mpts[n].Az
			}
			mpts[n].Set = WP_INIT

			if llat != 0.0 && llon != 0.0 {
				_, dm := geo.Csedist(llat, llon, mi.Lat, mi.Lon)
				d += dm * 1852.0
			}
			mpts[n].D = d
			llat = mi.Lat
			llon = mi.Lon
			n += 1
		}
	}
	if needrth > 0 {
		mpts[n].Wpno = -1
		mpts[n].Wpname = "RTH"
		mpts[n].Gz = elev[0]
		mpts[n].Mz = Conf.Rthalt
		mpts[n].Az = elev[0] + Conf.Rthalt
		mpts[n].Xz = mpts[n].Az
		mpts[n].Flag = 0
		mpts[n].Set = WP_RTH
		_, dm := geo.Csedist(Homep.Y, Homep.X, m.MissionItems[needrth].Lat, m.MissionItems[needrth].Lon)
		d += dm * 1852.0
		mpts[n].D = d
	}
}

func fixup_case(dat []byte) []byte {
	d := strings.Replace(string(dat), "MISSIONITEM", "missionitem", -1)
	d = strings.Replace(d, "MISSION", "mission", -1)
	return []byte(d)
}
