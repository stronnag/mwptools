package main

import (
	"fmt"
	//	geo "github.com/stronnag/bbl2kml/pkg/geo"
	kml "github.com/twpayne/go-kml"
	"github.com/twpayne/go-kml/icon"
	"image/color"
	"io"
	"os"
)

func zone_styles() []kml.Element {
	return []kml.Element{
		kml.SharedStyle(
			"styleINC",
			kml.IconStyle(
				kml.Scale(1.0),
				kml.Icon(
					kml.Href(icon.PaddleHref("grn-circle")),
				),
				kml.Color(color.RGBA{R: 0, G: 0xff, B: 0, A: 0xa0}),
			),
			kml.LineStyle(
				kml.Width(4.0),
				kml.Color(color.RGBA{R: 0, G: 0xff, B: 0, A: 0xa0}),
			),
			kml.PolyStyle(
				kml.Color(color.RGBA{R: 0, G: 0xff, B: 0, A: 0x1a}),
			),
		),
		kml.SharedStyle(
			"styleEXC",
			kml.IconStyle(
				kml.Scale(1.0),
				kml.Icon(
					kml.Href(icon.PaddleHref("red-circle")),
				),
				kml.Color(color.RGBA{R: 0xff, G: 0, B: 0, A: 0xa0}),
			),
			kml.LineStyle(
				kml.Width(4.0),
				kml.Color(color.RGBA{R: 0xff, G: 0, B: 0, A: 0xa0}),
			),
			kml.PolyStyle(
				kml.Color(color.RGBA{R: 0xff, G: 0, B: 0, A: 0x1a}),
			),
		),
	}
}

func get_style(t int) string {
	var st string
	if t == TYPE_EXC {
		st = "#styleEXC"
	} else {
		st = "#styleINC"
	}
	return st
}

func add_poly(g GeoZone, nop, pline bool) kml.Element {
	var points []kml.Coordinate
	var wps []kml.Element
	st := get_style(g.gtype)
	for i, pt := range g.points {
		if !nop {
			p := kml.Placemark(
				kml.Name(fmt.Sprintf("%d", i+1)),
				kml.StyleURL(st),
				kml.Point(
					kml.AltitudeMode(kml.AltitudeModeRelativeToGround),
					kml.Coordinates(kml.Coordinate{Lon: pt.lon, Lat: pt.lat, Alt: float64(g.maxalt)}),
				),
			).Add(kml.Visibility(true))
			wps = append(wps, p)
		}
		points = append(points, kml.Coordinate{Lon: pt.lon, Lat: pt.lat, Alt: float64(g.maxalt)})
	}
	points = append(points, points[0])
	track := kml.Placemark(
		kml.Name(fmt.Sprintf("Track %d", g.zid)),
		kml.Description(fmt.Sprintf("Polyline Track %d", g.zid)),
		kml.StyleURL(st))
	if pline {
		track.Add(
			kml.LineString(
				kml.AltitudeMode(kml.AltitudeModeRelativeToGround),
				kml.Extrude(true),
				kml.Tessellate(false),
				kml.Coordinates(points...),
			),
		)
	} else {
		track.Add(
			kml.Polygon(
				kml.AltitudeMode(kml.AltitudeModeRelativeToGround),
				kml.Extrude(true),
				kml.Tessellate(false),
				kml.OuterBoundaryIs(
					kml.LinearRing(
						kml.Coordinates(points...),
					),
				),
			),
		)
	}
	name := fmt.Sprintf("Poly %d", g.zid)
	desc := fmt.Sprintf(g.to_string())
	kml := kml.Folder(kml.Name(name)).Add(kml.Description(desc)).Add(kml.Visibility(true)).Add(track)
	if !nop {
		kml.Add(wps...)
	}
	return kml
}

func add_circle(g GeoZone, nop, pline bool) kml.Element {
	var points []kml.Coordinate
	var wps []kml.Element
	st := get_style(g.gtype)
	if !nop {
		p := kml.Placemark(
			kml.Name(""),
			kml.StyleURL(st),
			kml.Point(
				kml.AltitudeMode(kml.AltitudeModeRelativeToGround),
				kml.Coordinates(kml.Coordinate{Lon: g.points[0].lon, Lat: g.points[0].lat, Alt: float64(g.maxalt)}),
			),
		).Add(kml.Visibility(true))
		wps = append(wps, p)
	}

	for j := 0; j < 360; j += 5 {
		lat, lon := project_point(g.points[0].lat, g.points[0].lon, float64(j), g.points[1].lat)
		points = append(points, kml.Coordinate{Lon: lon, Lat: lat, Alt: float64(g.maxalt / 100.0)})
	}
	points = append(points, points[0])
	track := kml.Placemark(
		kml.Name(fmt.Sprintf("Circle %d", g.zid)),
		kml.Description(fmt.Sprintf("Circle Zone %d", g.zid)),
		kml.StyleURL(st))

	if pline {
		track.Add(
			kml.LineString(
				kml.AltitudeMode(kml.AltitudeModeRelativeToGround),
				kml.Extrude(true),
				kml.Tessellate(false),
				kml.Coordinates(points...),
			),
		)
	} else {
		track.Add(
			kml.Polygon(
				kml.AltitudeMode(kml.AltitudeModeRelativeToGround),
				kml.Extrude(true),
				kml.Tessellate(false),
				kml.OuterBoundaryIs(
					kml.LinearRing(
						kml.Coordinates(points...),
					),
				),
			),
		)
	}
	name := fmt.Sprintf("Circle %d", g.zid)
	desc := fmt.Sprintf(g.to_string())
	kml := kml.Folder(kml.Name(name)).Add(kml.Description(desc)).Add(kml.Visibility(true)).Add(track)
	if !nop {
		kml.Add(wps...)
	}
	return kml
}

func kmlBuild(name string, gzones []GeoZone, nop, pline bool) kml.Element {
	d := kml.Folder(kml.Name(name)).Add(kml.Open(true))
	d.Add(zone_styles()...)
	for _, g := range gzones {
		switch g.shape {
		case SHAPE_CIRCLE:
			d.Add(add_circle(g, nop, pline))
		case SHAPE_POLY:
			d.Add(add_poly(g, nop, pline))
		}
	}
	return d
}

func KMLFile(fn string, kname string, gzones []GeoZone, nop, pline bool, cname string) {
	kname = fmt.Sprintf("Zones for craft \"%s\"", cname)
	d := kmlBuild(kname, gzones, nop, pline)
	k := kml.KML(d)
	var f io.WriteCloser
	if len(fn) == 0 || fn == "-" {
		f = os.Stdout
	} else {
		f, _ = os.Create(fn)
		defer f.Close()
	}
	k.WriteIndent(f, "", "  ")
}
