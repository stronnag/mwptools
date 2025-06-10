package main

import (
	"fmt"
	"net"
)

const (
	state_INIT = iota
	state_M
	state_X_HEADER2
	state_X_FLAGS
	state_X_ID1
	state_X_ID2
	state_X_LEN1
	state_X_LEN2
	state_X_DATA
	state_X_CHECKSUM
)

const (
	sMSP_UNK = iota
	sMSP_OK
	sMSP_DIRN
	sMSP_CRC
	sMSP_TIMEOUT
	sMSP_FAIL
)

func crc8_dvb_s2(crc byte, a byte) byte {
	crc ^= a
	for i := 0; i < 8; i++ {
		if (crc & 0x80) != 0 {
			crc = (crc << 1) ^ 0xd5
		} else {
			crc = crc << 1
		}
	}
	return crc
}

func (sc *SChan) reencode() {
	if sc.owner != 0 {
		fmt.Printf("Rewrite message\n")
		sc.buf[3] |= (sc.owner << 2)
		crc := byte(0)
		for _, b := range sc.buf[3 : sc.len+8] {
			crc = crc8_dvb_s2(crc, b)
		}
		sc.buf[8+sc.len] = crc
	}
}

func (sc *SChan) msp_parse(inp []byte, nb int) {
	//fmt.Printf("Parser %d\n", nb)
	for i := 0; i < nb; i++ {
		//fmt.Printf("%d: State %d %02x\n", i, sc.state, inp[i])
		switch sc.state {
		case state_INIT:
			if inp[i] == '$' {
				sc.state = state_M
				sc.ok = sMSP_UNK
				sc.buf[0] = '$'
				sc.len = 0
			}
		case state_M:
			if inp[i] == 'X' {
				sc.state = state_X_HEADER2
				sc.buf[1] = inp[i]
			} else {
				sc.state = state_INIT
			}

		case state_X_HEADER2:
			sc.buf[2] = inp[i]
			if inp[i] == '!' {
				sc.state = state_X_FLAGS
				sc.ok = sMSP_DIRN
			} else if inp[i] == '>' || inp[i] == '<' {
				sc.state = state_X_FLAGS
				sc.ok = sMSP_OK
			} else {
				sc.state = state_INIT
			}

		case state_X_FLAGS:
			sc.buf[3] = inp[i]
			sc.crc = crc8_dvb_s2(0, inp[i])
			sc.state = state_X_ID1

		case state_X_ID1:
			sc.crc = crc8_dvb_s2(sc.crc, inp[i])
			sc.buf[4] = inp[i]
			sc.state = state_X_ID2

		case state_X_ID2:
			sc.crc = crc8_dvb_s2(sc.crc, inp[i])
			sc.buf[5] = inp[i]
			sc.state = state_X_LEN1

		case state_X_LEN1:
			sc.crc = crc8_dvb_s2(sc.crc, inp[i])
			sc.len = uint16(inp[i])
			sc.buf[6] = inp[i]
			sc.state = state_X_LEN2

		case state_X_LEN2:
			sc.crc = crc8_dvb_s2(sc.crc, inp[i])
			sc.len |= (uint16(inp[i]) << 8)
			sc.buf[7] = inp[i]
			sc.count = 8
			if sc.len > 0 {
				sc.state = state_X_DATA
			} else {
				sc.state = state_X_CHECKSUM
			}
		case state_X_DATA:
			sc.crc = crc8_dvb_s2(sc.crc, inp[i])
			sc.buf[sc.count] = inp[i]
			sc.count++
			if sc.count == 8+sc.len {
				sc.state = state_X_CHECKSUM
			}

		case state_X_CHECKSUM:
			ccrc := inp[i]
			sc.buf[sc.count] = inp[i]
			sc.count++
			if sc.crc != ccrc {
				sc.ok = sMSP_CRC
			} else {
				sc.publish()
			}
			sc.state = state_INIT
		}
	}
}

func (sc *SChan) publish() {
	if sc.owner == 0xff {
		owner := (sc.buf[3] >> 2)
		ua := addr_for_id(owner)
		if verbose > 0 {
			fmt.Printf("Out: Conn Write %d %d\n", sc.count, sc.len)
		}
		uaddr, _ := net.ResolveUDPAddr("udp", ua)
		conn.WriteTo(sc.buf[:sc.count], uaddr)
	} else {
		sc.reencode()
		if verbose > 0 {
			fmt.Printf("Out: Serial Write %d %d\n", sc.count, sc.len)
		}
		serdev.Write(sc.buf[:sc.count])
	}
}
