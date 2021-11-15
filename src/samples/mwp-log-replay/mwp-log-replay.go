package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"strconv"
	"time"
	"go.bug.st/serial"
	"encoding/binary"
	"encoding/json"
	"io"
	"bufio"
	"net"
	"regexp"
)

type JSONu8Slice []uint8
type JSItem struct {
	Stamp    float64     `json:"stamp"`
	Length   uint16      `json:"length"`
	Dirn     byte        `json:"direction"`
	RawBytes JSONu8Slice `json:"rawdata"`
}

var (
	_baud   = flag.Int("b", 115200, "Baud rate")
	_device = flag.String("d", "", "(serial) Device [device node, BT Addr (linux), udp/tcp URI]")
	_delay  = flag.Float64("delay", 0.01, "Delay (s) for non-v2 logs")
	_noskip = flag.Bool("wait-first", false, "honour first delay")
)

type SerDev interface {
	Read(buf []byte) (int, error)
	Write(buf []byte) (int, error)
	Close() error
}

type header struct {
	Offset float64
	Size   uint16
	Dirn   byte
}

const (
	LOG_LEGACY = 0
	LOG_V2     = 2
	LOG_JSON   = 42
)

type MWPLog struct {
	fh    *os.File
	rd    *bufio.Reader
	last  float64
	vers  byte
	skip  bool
	noout bool
}

const (
	DevClass_TCP = 0
	DevClass_UDP = 1
)

type IPDev struct {
	proto byte
	name  string
	port  int
}

func check_device() (string, int) {
	var baud int
	ss := strings.Split(*_device, "@")
	name := ss[0]
	if len(ss) > 1 {
		baud, _ = strconv.Atoi(ss[1])
	} else {
		baud = *_baud
	}
	if name == "" {
		for _, v := range []string{"/dev/ttyACM0", "/dev/ttyUSB0"} {
			if _, err := os.Stat(v); err == nil {
				name = v
				baud = *_baud
				break
			}
		}
	}
	if name != "" {
		log.Printf("Using device %s\n", name)
	}
	return name, baud
}

func (l *MWPLog) readlog() ([]byte, error) {
	var err error
	delay := 0.0
	var buf []byte

	switch l.vers {
	case LOG_V2:
		hdr := header{}
		err = binary.Read(l.fh, binary.LittleEndian, &hdr)
		if err == nil {
			delay = hdr.Offset - l.last
			l.last = hdr.Offset
			buf = make([]byte, hdr.Size)
			l.fh.Read(buf)
		}
	case LOG_JSON:
		dat, err0 := l.rd.ReadBytes('\n')
		if err0 == nil {
			var js JSItem
			err = json.Unmarshal(dat, &js)
			buf = js.RawBytes
			delay = js.Stamp - l.last
		} else {
			err = err0
		}

	default:
		buf = make([]byte, 16)
		_, err = l.fh.Read(buf)
		if *_delay != 0.0 {
			delay = *_delay
		} else {
			delay = 0.01
		}
	}

	if l.skip == false && delay > 0 {
		dt := time.Duration(delay * 1000000)
		if l.noout == false {
			//			fmt.Fprintf(os.Stderr, "sleep: %+v %f\n", dt*time.Microsecond, delay)
			time.Sleep(dt * time.Microsecond)
		}
	}
	l.skip = false
	return buf, err
}

func (l *MWPLog) checkvers() {
	sig := make([]byte, 3)
	_, err := l.fh.Read(sig)
	if err == nil {
		switch string(sig) {
		case "v2\n":
			l.vers = LOG_V2
		case `{"s`:
			l.vers = LOG_JSON
			l.fh.Seek(0, 0)
			l.rd = bufio.NewReader(l.fh)
		}
	}
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of mwp-serial-cap [options] file\n")
		flag.PrintDefaults()
	}
	flag.Parse()

	adata := flag.Args()
	if len(adata) == 0 {
		log.Fatalln("No input file given")
	}

	logf := MWPLog{vers: LOG_LEGACY, last: 0.0, skip: !*_noskip}
	fh, err := os.Open(adata[0])
	if err != nil {
		log.Fatal("open ", err)
	} else {
		logf.fh = fh
	}

	defer logf.fh.Close()

	var sd SerDev

	name, baud := check_device()
	logf.noout = (name == "")

	if name != "" {
		r := regexp.MustCompile(`^(tcp|udp)://(__MWP_SERIAL_HOST|[\[\]:A-Za-z\-\.0-9]*):(\d+)`)
		m := r.FindAllStringSubmatch(name, -1)
		if len(m) > 0 {
			dd := IPDev{}
			if m[0][1] == "tcp" {
				dd.proto = DevClass_TCP
			} else {
				dd.proto = DevClass_UDP
			}
			dd.name = m[0][2]
			/*
				if dd.name == "__MWP_SERIAL_HOST" {
					dd.name = resolve_default_gw()
				}
			*/
			dd.port, _ = strconv.Atoi(m[0][3])
			switch dd.proto {
			case DevClass_TCP:
				var conn net.Conn
				remote := fmt.Sprintf("%s:%d", dd.name, dd.port)
				addr, err := net.ResolveTCPAddr("tcp", remote)
				if err == nil {
					conn, err = net.DialTCP("tcp", nil, addr)
				}
				if err != nil {
					log.Fatal(err)
				}
				sd = conn
			case DevClass_UDP:
				var laddr, raddr *net.UDPAddr
				var conn net.Conn
				var err error
				if dd.name == "" {
					laddr, err = net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", dd.name, dd.port))
				} else {
					raddr, err = net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", dd.name, dd.port))
				}
				if err == nil {
					conn, err = net.DialUDP("udp", laddr, raddr)
				}
				if err != nil {
					log.Fatal(err)
				}
				sd = conn
			}
		} else {
			if len(name) == 17 && name[2] == ':' && name[8] == ':' && name[14] == ':' {
				sd = NewBT(name)
			} else {
				mode := &serial.Mode{BaudRate: baud}
				s, err := serial.Open(name, mode)
				if err != nil {
					log.Fatal(err)
				}
				sd = s
				if strings.Contains(name, "rfcomm") {
					time.Sleep(2 * time.Second)
				}
			}
		}
		defer sd.Close()
	}

	logf.checkvers()

	for {
		buf, err := logf.readlog()
		if err == nil {
			if name != "" {
				sd.Write(buf)
			} else {
				fmt.Printf("Read %d bytes\n", len(buf))
				for _, bx := range buf {
					fmt.Printf("%02x ", bx)
				}
				fmt.Println()
			}
		} else if err == io.EOF {
			break
		} else {
			log.Fatal(err)
		}
	}
	if name != "" {
		fmt.Printf("Close\n")
		sd.Close()
	}
}
