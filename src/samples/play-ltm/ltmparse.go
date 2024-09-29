package main

import (
	"encoding/binary"
	"fmt"
)

type State byte

const (
	state_INIT State = iota
	state_T
	state_FUNC
	state_DATA
	state_CRC
)

type LTM struct {
	len     byte
	count   byte
	crc     byte
	state   State
	cmd     byte
	payload []byte
}

func NewLTMParser() *LTM {
	return &LTM{}
}

func (l *LTM) zero() {
	l.len = 0
	l.count = 0
	l.crc = 0
	l.state = 0
	l.cmd = 0
	l.payload = []byte{}
}

func (l *LTM) Parse(inp []byte) {
	for _, b := range inp {
		switch l.state {
		case state_INIT:
			if b == '$' {
				l.state = state_T
			}
		case state_T:
			if b == 'T' {
				l.state = state_FUNC
			} else {
				l.state = state_INIT
			}
		case state_FUNC:
			l.state = state_DATA
			l.cmd = b
			switch l.cmd {
			case 'G', 'O':
				l.len = 14
			case 'A', 'N', 'X':
				l.len = 6
			case 'S':
				l.len = 7
			default:
				l.state = state_INIT
			}

			if l.state == state_DATA {
				l.payload = make([]byte, l.len)
			}

		case state_DATA:
			l.crc ^= b
			l.payload[l.count] = b
			l.count++
			if l.count == l.len {
				l.state = state_CRC
			}
		case state_CRC:
			if l.crc == b {
				l.display()
			}
			l.zero()
		}
	}
}

func (l *LTM) display() {
	switch l.cmd {
	case 'G':
		fmt.Printf("G => lat: %.6f lon: %.6f spd: %d alt: %.2f fix: %d sats %d\n",
			float64(int32(binary.LittleEndian.Uint32(l.payload[0:4])))/1e7,
			float64(int32(binary.LittleEndian.Uint32(l.payload[4:8])))/1e7,
			l.payload[8],
			float64(int32(binary.LittleEndian.Uint32(l.payload[9:13])))/100,
			l.payload[13]&3, l.payload[13]>>2)
	case 'A':
		fmt.Printf("A => p: %d r: %d y: %d\n",
			int16(binary.LittleEndian.Uint16(l.payload[0:2])),
			int16(binary.LittleEndian.Uint16(l.payload[2:4])),
			int16(binary.LittleEndian.Uint16(l.payload[4:6])))
	case 'S':
		fmt.Printf("S => volt: %.2f curr: %.3f  rssi: %d%% aspd: %d status 0x%x\n",
			float64(binary.LittleEndian.Uint16(l.payload[0:2]))/1000,
			float64(binary.LittleEndian.Uint16(l.payload[2:4]))/1000,
			int(l.payload[4])*100/255, l.payload[5], l.payload[6])
	case 'O':
		fmt.Printf("O => hlat: %.6f hlon: %.6f hfix: %d\n",
			float64(int32(binary.LittleEndian.Uint32(l.payload[0:4])))/1e7,
			float64(int32(binary.LittleEndian.Uint32(l.payload[4:8])))/1e7, l.payload[13])
	case 'X':
		fmt.Printf("X => hdop %.2f hwstatus 0x%x cnt: %d disarm %d\n",
			float64(binary.LittleEndian.Uint16(l.payload[0:2]))/100, l.payload[2], l.payload[3], l.payload[4])
	case 'N':
		fmt.Printf("N => gpsmode: %d navmode %d navaction %d wpno %d naverr %d\n",
			l.payload[0], l.payload[1], l.payload[2], l.payload[3], l.payload[4])
	default:
	}
}
