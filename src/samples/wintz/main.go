package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"gopkg.in/xmlpath.v2"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
)

// From
// https://github.com/unicode-org/cldr/blob/main/common/supplemental/windowsZones.xml
//

func find_zone(olsen string) (string, error) {
	file, err := os.Open("windowsZones.xml")
	if err != nil {
		return "", err
	}
	defer file.Close()

	var value string
	zstr := fmt.Sprintf("/supplementalData/windowsZones/mapTimezones/mapZone[@type='%s']/@other", olsen)
	path := xmlpath.MustCompile(zstr)
	root, err := xmlpath.Parse(file)
	if err != nil {
		log.Fatal(err)
	}
	value, _ = path.String(root)
	return value, err
}

func main() {
	lat := float64(0)
	lon := float64(0)
	dbname := ""
	zone := ""

	flag.StringVar(&dbname, "xml", "", "XML zone definitions")
	flag.Parse()
	args := flag.Args()

	if len(args) == 2 {
		var err error
		if lat, err = strconv.ParseFloat(args[0], 64); err == nil {
			if lon, err = strconv.ParseFloat(args[1], 64); err == nil {
				req := fmt.Sprintf("https://api.geotimezone.com/public/timezone?latitude=%f&longitude=%f", lat, lon)
				response, err := http.Get(req)
				if err == nil {
					defer response.Body.Close()
					content, err := ioutil.ReadAll(response.Body)
					if err == nil {
						var o map[string]interface{}
						json.Unmarshal(content, &o)
						if k, ok := o["iana_timezone"]; ok && k != nil {
							str := k.(string)
							if dbname == "" {
								zone = str
							} else {
								zone, _ = find_zone(str)
							}
						}
						fmt.Printf("%s\n", zone)
					}
				}
			}
		}
	}
}
