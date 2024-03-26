package main

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"os"
	"strings"
)

type FWApproach struct {
	No      int8   `xml:"no,attr" json:"no"`
	Index   int8   `xml:"index,attr" json:"index"`
	Appalt  int32  `xml:"approachalt,attr" json:"appalt"`
	Landalt int32  `xml:"landalt,attr" json:"landalt"`
	Dirn1   int16  `xml:"landheading1,attr" json:"dirn1"`
	Dirn2   int16  `xml:"landheading2,attr" json:"dirn2"`
	Dref    string `xml:"approachdirection,attr" json:"dref"`
	Aref    bool   `xml:"sealevelref,attr" json:"aref"`
}

type MissionItem struct {
	No     int     `xml:"no,attr" json:"no"`
	Action string  `xml:"action,attr" json:"action"`
	Lat    float64 `xml:"lat,attr" json:"lat"`
	Lon    float64 `xml:"lon,attr" json:"lon"`
	Alt    int32   `xml:"alt,attr" json:"alt"`
	P1     int16   `xml:"parameter1,attr" json:"p1"`
	P2     int16   `xml:"parameter2,attr" json:"p2"`
	P3     int16   `xml:"parameter3,attr" json:"p3"`
	Flag   uint8   `xml:"flag,attr,omitempty" json:"flag,omitempty"`
}

type MissionMWP struct {
	Zoom      int           `xml:"zoom,attr" json:"zoom"`
	Cx        float64       `xml:"cx,attr" json:"cx"`
	Cy        float64       `xml:"cy,attr" json:"cy"`
	Homex     float64       `xml:"home-x,attr" json:"home-x"`
	Homey     float64       `xml:"home-y,attr" json:"home-y"`
	Stamp     string        `xml:"save-date,attr" json:"save-date"`
	Generator string        `xml:"generator,attr" json:"generator"`
	Details   MissionDetail `xml:"details,omitempty" json:"details,omitempty"`
}

type Version struct {
	Value string `xml:"value,attr"`
}

type MissionDetail struct {
	Distance struct {
		Units string `xml:"units,attr,omitempty" json:"units,omitempty"`
		Value int    `xml:"value,attr,omitempty" json:"value,omitempty"`
	} `xml:"distance,omitempty" json:"distance,omitempty"`
}

type MissionSegment struct {
	Metadata     MissionMWP    `xml:"meta" json:"meta"`
	MissionItems []MissionItem `xml:"missionitem" json:"mission"`
	FWApproach   FWApproach    `xml:"fwapproach,omitempty" json:"fwapproach"`
}

type MultiMission struct {
	XMLName xml.Name         `xml:"mission"  json:"-"`
	Version Version          `xml:"version" json:"-"`
	Comment string           `xml:",comment" json:"-"`
	Segment []MissionSegment `json:"missions"`
}

type Mission struct {
	XMLName      xml.Name      `xml:"mission"  json:"-"`
	Version      Version       `xml:"version" json:"-"`
	Comment      string        `xml:",comment" json:"-"`
	Metadata     MissionMWP    `xml:"meta" json:"meta"`
	MissionItems []MissionItem `xml:"missionitem" json:"mission"`
	FWApproach   FWApproach    `xml:"fwapproach,omitempty" json:"fwapproach"`
	mission_file string        `xml:"-" json:"-"`
}

func (ml *MissionSegment) MarshalXML(e *xml.Encoder, start xml.StartElement) error {
	if err := e.EncodeElement(ml.Metadata, xml.StartElement{Name: xml.Name{Local: "meta"}}); err != nil {
		return err
	}
	for _, mi := range ml.MissionItems {
		if err := e.EncodeElement(mi, xml.StartElement{Name: xml.Name{Local: "missionitem"}}); err != nil {
			return err
		}
	}

	if ml.FWApproach.No > 7 && ml.FWApproach.Dirn1 != 0 && ml.FWApproach.Dirn2 != 0 {
		err := e.EncodeElement(ml.FWApproach, xml.StartElement{Name: xml.Name{Local: "fwapproach"}})
		return err
	}
	return nil
}

func NewMultiMission(mis []MissionItem) *MultiMission {
	mm := &MultiMission{Segment: []MissionSegment{{}}}
	if mis != nil {
		segno := 0
		no := 1
		for j := range mis {
			mis[j].No = no
			no++
			mm.Segment[segno].MissionItems = append(mm.Segment[segno].MissionItems, mis[j])
			if mis[j].Flag == 0xa5 {
				if j != len(mis)-1 {
					mm.Segment = append(mm.Segment, MissionSegment{})
					segno++
					no = 1
				}
			}
		}
		if no > 1 {
			mm.Segment[segno].MissionItems[no-2].Flag = 0xa5
		}
	}
	return mm
}

func (mi *MissionItem) is_GeoPoint() bool {
	a := mi.Action
	return !(a == "RTH" || a == "SET_HEAD" || a == "JUMP")
}

func ReadMissionFile(fn string) (*MultiMission, error) {
	v := Version{}
	mwps := []MissionMWP{}
	mis := []MissionItem{}
	fwa := []FWApproach{}

	dat, err := os.ReadFile(fn)
	if err != nil {
		return nil, err
	}
	buf := bytes.NewBuffer(dat)
	dec := xml.NewDecoder(buf)
	for {
		t, _ := dec.Token()
		if t == nil {
			break
		}
		switch se := t.(type) {
		case xml.StartElement:
			switch strings.ToLower(se.Name.Local) {
			case "mission":
			case "version":
				dec.DecodeElement(&v, &se)
			case "mwp", "meta":
				var mwp MissionMWP
				dec.DecodeElement(&mwp, &se)
				mwps = append(mwps, mwp)
			case "missionitem":
				var mi MissionItem
				dec.DecodeElement(&mi, &se)
				mis = append(mis, mi)
			case "fwapproach":
				var f FWApproach
				dec.DecodeElement(&f, &se)
				fwa = append(fwa, f)
			default:
				fmt.Printf("Unknown MWXML tag %s\n", se.Name.Local)
			}
		}
	}
	mm := NewMultiMission(mis)
	mm.Version = v
	for j := range mm.Segment {
		if j < len(mwps) {
			mm.Segment[j].Metadata = mwps[j]
		}
		for k := range fwa {
			if fwa[k].Index == int8(j) {
				mm.Segment[j].FWApproach = fwa[k]
			}
		}
	}
	return mm, nil
}
