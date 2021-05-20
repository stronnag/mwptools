package main

import (
	"errors"
	"fmt"
	"github.com/tarm/serial"
	"log"
	"os"
	"io"
	"net"
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
	p *serial.Port
	conn net.Conn
	r io.ReadCloser
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
				case 'G','O':
					len = 14
				case 'A','N','X':
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
		conn,err = net.DialUDP("udp", laddr, raddr)
	}
	if err != nil {
		log.Fatal(err)
	}
	return &LTMSerial{klass: dd.klass, conn: conn}
}

func (m *LTMSerial) Send_ltm(payload []byte) (int,error) {
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
		for i:=3; i < 10; i++ {
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
   default:
		fmt.Fprintln(os.Stderr, "Unsupported device")
		os.Exit(1)
	}

	var err error
	m.r, err = os.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	return m
}
