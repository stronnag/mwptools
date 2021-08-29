package main

import (
	"fmt"
	"go.bug.st/serial"
	"log"
	"net"
	"os"
	"regexp"
	"strings"
	"strconv"
)

const (
	DevClass_NONE = iota
	DevClass_SERIAL
	DevClass_TCP
	DevClass_UDP
	DevClass_BT
	DevClass_FILE
	DevClass_FD
)

type DevDescription struct {
	klass  int
	name   string
	param  int
	name1  string
	param1 int
}

type MSPSerial struct {
	klass int
	sd    SerDev
}

func parse_device(device string, baud int) DevDescription {
	dd := DevDescription{name: "", klass: DevClass_NONE}
	r := regexp.MustCompile(`^(tcp|udp)://([\[\]:A-Za-z\-\.0-9]*):(\d+)/{0,1}([A-Za-z\-\.0-9]*):{0,1}(\d*)`)
	m := r.FindAllStringSubmatch(device, -1)
	if len(m) > 0 {
		if m[0][1] == "tcp" {
			dd.klass = DevClass_TCP
		} else {
			dd.klass = DevClass_UDP
		}
		dd.name = m[0][2]
		dd.param, _ = strconv.Atoi(m[0][3])
		// These are only used for ESP8266 UDP
		dd.name1 = m[0][4]
		dd.param1, _ = strconv.Atoi(m[0][5])
	} else if len(device) == 17 && (device)[2] == ':' && (device)[8] == ':' && (device)[14] == ':' {
		dd.name = device
		dd.klass = DevClass_BT
	} else {
		ss := strings.Split(device, "@")
		dd.klass = DevClass_SERIAL
		dd.name = ss[0]
		if len(ss) > 1 {
			dd.param, _ = strconv.Atoi(ss[1])
		} else {
			dd.param = baud
		}
	}
	return dd
}

func check_device(device string, baud int) DevDescription {
	devdesc := parse_device(device, baud)
	if devdesc.name == "" {
		for _, v := range []string{"/dev/ttyACM0", "/dev/ttyUSB0"} {
			if _, err := os.Stat(v); err == nil {
				devdesc.klass = DevClass_SERIAL
				devdesc.name = v
				devdesc.param = baud
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


func (m *MSPSerial) Klass() int {
	return m.klass
}

func NewMSPFd(fd int) *MSPSerial {
	fh := os.NewFile(uintptr(fd), "pipe")
	return &MSPSerial{klass: DevClass_FD, sd: fh}
}

func NewMSPFile(fn string) *MSPSerial {
	fh, _ := os.Create(fn)
	return &MSPSerial{klass: DevClass_FILE, sd: fh}
}

func NewMSPSerial(device string, baud int) *MSPSerial {
	dd := check_device(device, baud)
	switch dd.klass {
	case DevClass_SERIAL:
		p, err := serial.Open(dd.name, &serial.Mode{BaudRate: dd.param})
		if err != nil {
			log.Fatal(err)
		}
		return &MSPSerial{klass: dd.klass, sd: p}
	case DevClass_BT:
		bt := NewBT(dd.name)
		return &MSPSerial{klass: dd.klass, sd: bt}
	case DevClass_TCP:
		var conn net.Conn
		remote := fmt.Sprintf("%s:%d", dd.name, dd.param)
		addr, err := net.ResolveTCPAddr("tcp", remote)
		if err == nil {
			conn, err = net.DialTCP("tcp", nil, addr)
		}
		if err != nil {
			log.Fatal(err)
		}
		return &MSPSerial{klass: dd.klass, sd: conn}
	case DevClass_UDP:
		var laddr, raddr *net.UDPAddr
		var conn net.Conn
		var err error
		if dd.param1 != 0 {
			raddr, err = net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", dd.name1, dd.param1))
			laddr, err = net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", dd.name, dd.param))
		} else {
			if dd.name == "" {
				laddr, err = net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", dd.name, dd.param))
			} else {
				raddr, err = net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", dd.name, dd.param))
			}
		}
		if err == nil {
			conn, err = net.DialUDP("udp", laddr, raddr)
		}
		if err != nil {
			log.Fatal(err)
		}
		return &MSPSerial{klass: dd.klass, sd: conn}
	default:
		fmt.Fprintln(os.Stderr, "Unsupported device")
		os.Exit(1)
	}
	return nil
}
