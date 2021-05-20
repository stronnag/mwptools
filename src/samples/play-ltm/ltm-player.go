package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"regexp"
	"strings"
	"strconv"
	"time"
)


const (
	DevClass_NONE = iota
	DevClass_SERIAL
	DevClass_TCP
	DevClass_UDP
)

type DevDescription  struct {
	klass int
	name string
	param int
	name1 string
	param1 int
}

var (
	baud   = flag.Int("b", 115200, "Baud rate")
	device = flag.String("d", "", "Serial Device")
)


func check_device() DevDescription {
	devdesc := parse_device()
	if devdesc.name == "" {
		for _, v := range []string{"/dev/ttyACM0", "/dev/ttyUSB0"} {
			if _, err := os.Stat(v); err == nil {
				devdesc.klass = DevClass_SERIAL
				devdesc.name = v
				devdesc.param = *baud
				break
			}
		}
	}

	if devdesc.name == "" {
		log.Fatalln("No device available")
	} else {
		log.Printf("Using device [%v]\n", devdesc.name)
	}
	return devdesc
}

func parse_device() DevDescription {
	dd := DevDescription{name: "", klass: DevClass_NONE }
	r := regexp.MustCompile(`^(tcp|udp)://([\[\]:A-Za-z\-\.0-9]*):(\d+)/{0,1}([A-Za-z\-\.0-9]*):{0,1}(\d*)`)
	m := r.FindAllStringSubmatch(*device,-1)
	if len(m) > 0 {
		if m[0][1] == "tcp" {
			dd.klass = DevClass_TCP
		} else {
			dd.klass = DevClass_UDP
		}
		dd.name = m[0][2]
		dd.param,_ = strconv.Atoi(m[0][3])
		// These are only used for ESP8266 UDP
		dd.name1 = m[0][4]
		dd.param1,_ = strconv.Atoi(m[0][5])
	} else {
		ss := strings.Split(*device,"@")
		dd.klass = 	DevClass_SERIAL
		dd.name = ss[0]
		if len(ss) > 1 {
			dd.param,_ = strconv.Atoi(ss[1])
		} else {
			dd.param = *baud
		}
	}
	return dd
}

func main() {

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of ltm-player [options] file\n")
		flag.PrintDefaults()
	}

	flag.Parse()
	files := flag.Args()
	if len(files) != 1 {
		log.Fatal("One file required\n")
	}
	devdesc := check_device()
	s := LTMInit(devdesc,files[0])

//	xtime := time.Time{}
// 	var xlast = int16(-1)

	for {
		buf,err := s.Read_ltm()
		if  err == nil  {
			if buf[2] == 'A' {
				time.Sleep(100 * time.Millisecond)
			} /** else if buf[2] == 'X' {
				if xlast != -1 {
					diff := int16(buf[6]) - xlast
					if diff < 0 {
						diff += 256
					}
				}
				t := time.Now();
				if ! xtime.IsZero() {
					d := t.Sub(xtime)
					fmt.Fprintf(os.Stderr, "XTIME %d\n", d.Milliseconds())
				}
				xtime = t
				xlast = int16(buf[6])
			} **/
			s.Send_ltm(buf)
		} else {
			s.Finish()
			log.Fatal(err)
		}
	}
}