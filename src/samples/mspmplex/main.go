package main

import (
	"flag"
	"fmt"
	"go.bug.st/serial"
	"go.bug.st/serial/enumerator"
	"log"
	"net"
	"os"
	"strings"
	"sync"
)

type SChan struct {
	len   uint16
	count uint16
	crc   uint8
	flags uint8
	owner uint8
	state uint8
	ok    uint8
	buf   [1024]byte
}

var sclist [64]SChan

var (
	verbose  int
	baudrate int
	sername  string
)

var smap map[string]byte
var rwm sync.RWMutex
var conn *net.UDPConn
var serdev serial.Port

func enumerate_ports() string {
	ports, err := enumerator.GetDetailedPortsList()
	if err != nil {
		log.Fatal(err)
	}
	for _, port := range ports {
		if port.Name != "" {
			if port.IsUSB {
				if port.VID == "0483" && port.PID == "5740" {
					return port.Name
				}
			}
		}
	}
	return ""
}

func main() {
	var err error
	var udpnam, devnam string

	baudrate = 115200
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [options] device [:port]\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
	}

	flag.IntVar(&verbose, "verbose", 0, "verbosity (0:none, 1:open/close, >1: 1 + address map)")
	flag.IntVar(&baudrate, "baudrate", baudrate, "set baud rate")

	flag.Parse()
	rest := flag.Args()
	for _, r := range rest {
		if r == "auto" || strings.Contains(r, "COM") || strings.HasPrefix(r, "/dev") {
			devnam = r
		}
		if strings.HasPrefix(r, ":") {
			udpnam = r
		}
	}

	if devnam == "" {
		devnam = "auto"
	}

	if udpnam == "" {
		udpnam = ":27072"
	}

	mode := &serial.Mode{
		BaudRate: baudrate,
	}

	fmt.Printf("Waiting for serial\n")
	for {
		portnam := ""
		if devnam == "auto" {
			portnam = enumerate_ports()
		} else {
			portnam = devnam
		}
		if portnam != "" {
			serdev, err = serial.Open(portnam, mode)
			if verbose > 0 {
				fmt.Printf("Open %s %+v\n", portnam, err)
			}
			if err == nil {
				go read_serial(serdev)
				break
			}
		}
	}

	Get_interface("vEthernet (WSL)")

	uaddr, err := net.ResolveUDPAddr("udp", udpnam)
	if err != nil {
		log.Fatal(err)
	}

	conn, err = net.ListenUDP("udp", uaddr)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	if verbose > 0 {
		fmt.Printf("Listening on %s\n", udpnam)
	}
	smap = make(map[string]byte)
	baseowner := byte(0)
	inp := make([]byte, 4096)
	for {
		n, addr, _ := conn.ReadFrom(inp)
		fmt.Printf("Read %d from %+v\n", n, addr)
		rwm.Lock()
		owner, ok := smap[addr.String()]
		rwm.Unlock()
		if !ok {
			owner = baseowner
			fmt.Printf("Allocate for %d\n", owner)
			rwm.Lock()
			smap[addr.String()] = owner
			rwm.Unlock()
			sclist[owner] = SChan{}
			baseowner++
			sclist[owner].owner = owner
			if verbose > 1 {
				fmt.Println("map:", smap)
			}
			if baseowner > 63 {
				log.Fatal("Too many clients\n")
			}
		}
		sclist[owner].msp_parse(inp, n)
	}
}

func addr_for_id(id byte) string {
	uas := ""
	rwm.Lock()
	for k, v := range smap {
		if v == id {
			uas = k
			break
		}
	}
	rwm.Unlock()
	return uas
}

func read_serial(s serial.Port) {
	inp := make([]byte, 4096)
	sc := SChan{}
	sc.owner = 0xff
	for {
		n, err := s.Read(inp)
		fmt.Printf("Serial Read %d\n", n)
		if err == nil && n > 0 {
			sc.msp_parse(inp, n)
		} else {
			fmt.Printf("Serial %v\n", err)
			break
		}
	}
}
