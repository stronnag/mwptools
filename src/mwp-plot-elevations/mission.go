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

func find_best_alt(mpts []Point, wpno int) {
	ba := -99999
	for _, m := range mpts {
		if m.Wpno == int8(wpno) {
			if m.Xz > ba {
				ba = m.Xz
			}
		}
	}
	for j, m := range mpts {
		if m.Wpno == int8(wpno) {
			mpts[j].Xz = ba
		}
	}
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
			if mi.Action == "LAND" && landno == -1 {
				landno = int8(mi.No)
			}
			find_best_alt(mpts, mi.No)
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
				lidx := landno - 1
				if m.MissionItems[lidx].Action != "LAND" {
					panic("LAND WP mismatch")
				}
				if m.MissionItems[lidx].P3 == 0 {
					m.MissionItems[lidx].P2 = int16(p.Gz - mpts[0].Gz)
				} else {
					m.MissionItems[lidx].P2 = int16(p.Gz)
				}
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
		dmm := int(dm * 1852)
		if dmm > Conf.Sanity {
			str := fmt.Sprintf("Acceptable first WP distance %d exceeded %d", dmm, Conf.Sanity)
			return errors.New(str)
		}
	}
	return nil
}

func (m *Mission) Get_points() []Point {
	mpts := []Point{}
	valid := false
	lx := 0.0
	ly := 0.0
	cx := 0.0
	cy := 0.0
	nsize := len(m.MissionItems)
	ret := false

	if Homep.Set == WP_HOME {
		Homep.Wpname = "HOME"
		mpts = append(mpts, Homep)
		mpts[0].Flag = 0
		mpts[0].Set = WP_HOME
		valid = true
		cx = Homep.X
		cy = Homep.Y
		lx = cx
		ly = cy
	}
	dist := 0.0
	jumpC := make([]int16, nsize)

	for j, mi := range m.MissionItems {
		if mi.Action == "JUMP" {
			jumpC[j] = mi.P2
		}
	}
	n := 0
	for {
		if n >= nsize {
			break
		}
		var typ = m.MissionItems[n].Action
		if valid {
			if typ == "SET_POI" || typ == "SET_HEAD" {
				n += 1
				continue
			}
			if typ == "JUMP" {
				if jumpC[n] == -1 {
					n += 1
				} else {
					if jumpC[n] == 0 {
						jumpC[n] = m.MissionItems[n].P2
						n += 1
					} else {
						jumpC[n] -= 1
						n = int(m.MissionItems[n].P1) - 1
					}
				}
				continue
			}

			if typ == "RTH" {
				ret = true
				break
			}
			mi := m.MissionItems[n]
			cy = mi.Lat
			cx = mi.Lon
			_, dm := geo.Csedist(ly, lx, cy, cx)
			dist += dm * 1852.0
			mpts = append(mpts, Point{Y: cy, X: cx, Wpno: int8(mi.No), D: dist,
				Wpname: fmt.Sprintf("WP%d", mi.No), Flag: int8(mi.P3), Set: WP_INIT,
				Mz: int(mi.Alt)})
			n += 1
		} else {
			cy = m.MissionItems[n].Lat
			cx = m.MissionItems[n].Lon
			valid = true
			n += 1
		}
		lx = cx
		ly = cy
	}

	if ret {
		_, dm := geo.Csedist(ly, lx, Homep.Y, Homep.X)
		dist += dm * 1852.0
		mpts = append(mpts, Point{Y: Homep.Y, X: Homep.X, Wpno: -1, Wpname: "RTH", D: dist,
			Flag: 0, Set: WP_RTH})
	}
	/*** Not used here
		var vpts map[int8][]int8
		vpts = make(map[int8][]int8)
		for i := 0; i < len(mpts)-1; i++ {
			m := mpts[i]
			nwp := mpts[i+1].Wpno

			need := true
			for j, _ := range vpts[m.Wpno] {
				if vpts[m.Wpno][j] == nwp {
					need = false
					break
				}
			}
			if need {
				vpts[m.Wpno] = append(vpts[m.Wpno], nwp)
			}
		}
		for k, v := range vpts {
			fmt.Fprintf(os.Stderr, "%d => %v\n", k, v)
		}
	  ***/
	return mpts
}

func (m *Mission) Update_details(mpts []Point, elev []int) {
	n := 0

	if mpts[0].Set == WP_HOME {
		mpts[0].Gz = elev[0]
		mpts[0].Mz = 0
		mpts[0].Az = elev[0]
		mpts[0].Xz = elev[0]
		n = 1
	}

	for ; n < len(mpts); n += 1 {
		if mpts[n].Wpno == -1 {
			mpts[n].Gz = elev[0]
			mpts[n].Mz = Conf.Rthalt
			mpts[n].Az = elev[0] + Conf.Rthalt
			mpts[n].Xz = mpts[n].Az
		} else {
			mpts[n].Gz = elev[n]
			alt := mpts[n].Mz
			if mpts[n].Flag == 0 {
				mpts[n].Az = elev[0] + alt
			} else {
				mpts[n].Mz -= elev[0]
				mpts[n].Az = alt
			}
			if Conf.Noalts {
				mpts[n].Xz = elev[n] + Conf.Margin
			} else {
				mpts[n].Xz = mpts[n].Az
			}
		}
	}
}

func fixup_case(dat []byte) []byte {
	d := strings.Replace(string(dat), "MISSIONITEM", "missionitem", -1)
	d = strings.Replace(d, "MISSION", "mission", -1)
	return []byte(d)
}
