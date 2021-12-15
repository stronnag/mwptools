package main

import (
	"errors"
	"fmt"
	"github.com/tarm/serial"
	"log"
	"os"
	"io"
	"net"
	"encoding/binary"
)

const (
	state_INIT = iota
	state_T
	state_FUNC
	state_DATA
	state_CRC
)

type LTMSerial struct {
	klass int
	p     *serial.Port
	conn  net.Conn
	r     io.ReadCloser
	lasts []byte
}

func (m *LTMSerial) Read_ltm() ([]byte, error) {
	inp := make([]byte, 1)
	var count = byte(0)
	var len = byte(0)
	var crc = byte(0)
	var cmd = byte(0)
	ok := true
	done := false
	var buf []byte

	n := state_INIT

	for !done {
		_, err := m.r.Read(inp)
		if err == nil {
			switch n {
			case state_INIT:
				if inp[0] == '$' {
					n = state_T
				}
			case state_T:
				if inp[0] == 'T' {
					n = state_FUNC
				} else {
					n = state_INIT
				}
			case state_FUNC:
				n = state_DATA
				cmd = inp[0]
				switch cmd {
				case 'G', 'O':
					len = 14
				case 'A', 'N', 'X':
					len = 6
				case 'S':
					len = 7
				default:
					n = state_INIT
				}
				if n == state_DATA {
					buf = make([]byte, len+4)
					buf[0] = '$'
					buf[1] = 'T'
					buf[2] = cmd
				}

			case state_DATA:
				buf[count+3] = inp[0]
				crc ^= inp[0]
				count++
				if count == len {
					n = state_CRC
				}
			case state_CRC:
				ccrc := inp[0]
				if crc == ccrc {
					ok = true
					buf[3+count] = crc
					if cmd == 'S' {
						m.lasts = buf
					}
				} else {
					ok = false
				}
				done = true
			}
		} else {
			return nil, err
		}
	}
	if !ok {
		return nil, errors.New("LTM error")
	} else {
		return buf, nil
	}
}

func NewLTMSerial(dd DevDescription) *LTMSerial {
	c := &serial.Config{Name: dd.name, Baud: dd.param}
	p, err := serial.OpenPort(c)
	if err != nil {
		log.Fatal(err)
	}
	return &LTMSerial{klass: dd.klass, p: p}
}

func NewLTMTCP(dd DevDescription) *LTMSerial {
	var conn net.Conn
	remote := fmt.Sprintf("%s:%d", dd.name, dd.param)
	addr, err := net.ResolveTCPAddr("tcp", remote)
	if err == nil {
		conn, err = net.DialTCP("tcp", nil, addr)
	}

	if err != nil {
		log.Fatal(err)
	}
	return &LTMSerial{klass: dd.klass, conn: conn}
}

func NewLTMUDP(dd DevDescription) *LTMSerial {
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
	return &LTMSerial{klass: dd.klass, conn: conn}
}

func (m *LTMSerial) Send_ltm(payload []byte) (int, error) {
	if m.klass == DevClass_SERIAL {
		return m.p.Write(payload)
	} else {
		return m.conn.Write(payload)
	}
}

func (m *LTMSerial) Finish() {
	if m.lasts != nil {
		m.lasts[9] = 0
		var crc = byte(0)
		for i := 3; i < 10; i++ {
			crc ^= m.lasts[i]
		}
		m.lasts[10] = crc
		m.Send_ltm(m.lasts)
	}
}

func LTMInit(dd DevDescription, path string) *LTMSerial {
	var m *LTMSerial
	switch dd.klass {
	case DevClass_SERIAL:
		m = NewLTMSerial(dd)
	case DevClass_TCP:
		m = NewLTMTCP(dd)
	case DevClass_UDP:
		m = NewLTMUDP(dd)
	case DevClass_NONE:
		m = &LTMSerial{klass: dd.klass}
	default:
		fmt.Fprintln(os.Stderr, "Unsupported / null device")
	}

	var err error
	m.r, err = os.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	return m
}

func decode_ltm(buf []byte) {
	if len(buf) > 4 {
		switch buf[2] {
		case 'G':
			fmt.Printf("G => lat: %.6f lon: %.6f spd: %d alt: %.2f fix: %d sats %d\n",
				float64(int32(binary.LittleEndian.Uint32(buf[3:7])))/1e7,
				float64(int32(binary.LittleEndian.Uint32(buf[7:11])))/1e7,
				buf[11],
				float64(int32(binary.LittleEndian.Uint32(buf[12:16])))/100,
				buf[16]&3, buf[16]>>2)
		case 'A':
			fmt.Printf("A => p: %d r: %d y: %d\n",
				int16(binary.LittleEndian.Uint16(buf[3:5])),
				int16(binary.LittleEndian.Uint16(buf[5:7])),
				int16(binary.LittleEndian.Uint16(buf[7:9])))
		case 'S':
			fmt.Printf("S => volt: %.2f curr: %.3f  rssi: %d%% aspd: %d status 0x%x\n",
				float64(binary.LittleEndian.Uint16(buf[3:5]))/1000,
				float64(binary.LittleEndian.Uint16(buf[5:7]))/1000,
				int(buf[7])*100/255, buf[8], buf[9])
		case 'O':
			fmt.Printf("O => hlat: %.6f hlon: %.6f hfix: %d\n",
				float64(int32(binary.LittleEndian.Uint32(buf[3:7])))/1e7,
				float64(int32(binary.LittleEndian.Uint32(buf[7:11])))/1e7, buf[16])
		case 'X':
			fmt.Printf("X => hdop %.2f hwstatus 0x%x cnt: %d disarm %d\n",
				float64(binary.LittleEndian.Uint16(buf[3:5]))/100, buf[5], buf[6], buf[7])
		case 'N':
			fmt.Printf("N => gpsmode: %d navmode %d navaction %d wpno %d naverr %d\n",
				buf[3], buf[4], buf[5], buf[6], buf[7])
		default:
		}
	}
}
