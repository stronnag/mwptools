package main

import (
	"fmt"
	"strings"
	"net/http"
	"io/ioutil"
	"encoding/json"
	"encoding/base64"
	"errors"
)

type GeoItem struct {
	jindex int
	lat    float64
	lon    float64
	alt    int32
	elev   int32
}

const bKey = "QWwxYnFHYU5vZGVOQTcxYmxlSldmakZ2VzdmQXBqSk9vaE1TWjJfSjBIcGd0NE1HZExJWURiZ3BnQ1piWjF4QQ=="

func parse_response(js []byte) []float64 {
	var elev []float64
	var result map[string]interface{}
	json.Unmarshal(js, &result)
	m0 := result["resourceSets"].([]interface{})
	for _, m00 := range m0 {
		m1 := m00.(map[string]interface{})
		m2 := m1["resources"].([]interface{})
		for _, m20 := range m2 {
			m3 := m20.(map[string]interface{})
			mx := m3["elevations"].([]interface{})
			for _, e := range mx {
				elev = append(elev, e.(float64))
			}
		}
	}
	return elev
}

func get_elevations(g []GeoItem) ([]float64, error) {
	var sb strings.Builder
	var elev []float64

	astr, err := base64.StdEncoding.DecodeString(bKey)
	sb.WriteString("http://dev.virtualearth.net/REST/v1/Elevation/List?points=")
	for i, p := range g {
		if i != 0 {
			sb.WriteByte(',')
		}
		sb.WriteString(fmt.Sprintf("%.7f,%.7f", p.lat, p.lon))
	}
	sb.WriteString("&key=")
	sb.WriteString(string(astr))
	req := sb.String()
	response, err := http.Get(req)
	if err == nil {
		defer response.Body.Close()
		contents, err := ioutil.ReadAll(response.Body)
		if err == nil && response.StatusCode == 200 {
			elev = parse_response(contents)
			if len(elev) != len(g) {
				err = errors.New("Return data mismatch")
			}
		}
	}
	return elev, err
}

func GetElevation(lat, lon float64) (float64, error) {
	var g []GeoItem
	g = append(g, GeoItem{0, lat, lon, 0, 0})
	elev, err := get_elevations(g)
	return elev[0], err
}
/**
func Elevation_for_Mission(m *Mission, hlat, hlon float64) ([]GeoItem, error) {
	var g []GeoItem
	g = append(g, GeoItem{0, hlat, hlon, 0, 0})
	for _, mi := range m.MissionItems {
		nogeo := (mi.Action == "RTH" || mi.Action == "SET_POI" || mi.Action == "JUMP")
		if !nogeo {
			g = append(g, GeoItem{mi.No, mi.Lat, mi.Lon, mi.Alt, 0})
		}
	}
	elev, err := get_elevations(g)
	for i := 0; i < len(g); i++ {
		diff := int32(elev[i] - elev[0])
		g[i].elev = g[i].alt - diff
	}
	return g, err
}
**/
