package main

import (
	"fmt"
	"io"
)

const (
	state_INIT = iota
	state_M
	state_DIRN
	state_LEN
	state_CMD
	state_DATA
	state_CRC

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
	msp_BOXNAMES        = uint16(116)
	msp_NAME            = uint16(10)
	msp2_COMMON_SETTING = uint16(0x1003)
)

type MsgData struct {
	ok   bool
	vers byte
	dirn byte
	cmd  uint16
	len  uint16
	data []byte
}

var count = uint16(0)
var crc = byte(0)
var n = state_INIT
var sc MsgData

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

func msp_output(mspfh io.WriteCloser, sc MsgData) {
	fmt.Fprintf(mspfh, "MSP%d %c (%d,0x%x) paylen=%d", sc.vers, sc.dirn, sc.cmd, sc.cmd, sc.len)
	if sc.cmd == msp2_COMMON_SETTING && sc.dirn == '<' {
		fmt.Fprintf(mspfh, " %s", string(sc.data[:sc.len-1]))
	} else if sc.dirn == '>' && (sc.cmd == msp_NAME || sc.cmd == msp_BOXNAMES) {
		fmt.Fprintf(mspfh, " %s", string(sc.data[:sc.len]))
	} else if sc.len > 0 {
		fmt.Fprintf(mspfh, " %s", HexArray(sc.data[:sc.len]))
	}
	fmt.Fprintln(mspfh)
}

func ts_output(mspfh io.WriteCloser, offset float64) {
	fmt.Fprintf(mspfh, "%8.3f ", offset)
}

func msp_parse(mspfh io.WriteCloser, inp []byte, offset float64) {
	for i, _ := range inp {
		switch n {
		case state_INIT:
			if inp[i] == '$' {
				n = state_M
				sc.ok = false
				sc.len = 0
				sc.cmd = 0
			}
		case state_M:
			if inp[i] == 'M' {
				sc.vers = 1
				n = state_DIRN
			} else if inp[i] == 'X' {
				sc.vers = 2
				n = state_X_HEADER2
			} else {
				n = state_INIT
			}
		case state_DIRN:
			sc.dirn = inp[i]
			if inp[i] == '!' {
				n = state_LEN
			} else if inp[i] == '<' || inp[i] == '>' {
				n = state_LEN
				sc.ok = true
			} else {
				n = state_INIT
			}

		case state_X_HEADER2:
			sc.dirn = inp[i]
			if inp[i] == '!' {
				n = state_X_FLAGS
			} else if inp[i] == '>' || inp[i] == '<' {
				n = state_X_FLAGS
				sc.ok = true
			} else {
				n = state_INIT
			}
		case state_X_FLAGS:
			crc = crc8_dvb_s2(0, inp[i])
			n = state_X_ID1

		case state_X_ID1:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.cmd = uint16(inp[i])
			n = state_X_ID2

		case state_X_ID2:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.cmd |= (uint16(inp[i]) << 8)
			n = state_X_LEN1

		case state_X_LEN1:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.len = uint16(inp[i])
			n = state_X_LEN2

		case state_X_LEN2:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.len |= (uint16(inp[i]) << 8)
			if sc.len > 0 {
				n = state_X_DATA
				count = 0
				sc.data = make([]byte, sc.len)
			} else {
				n = state_X_CHECKSUM
			}
		case state_X_DATA:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.data[count] = inp[i]
			count++
			if count == sc.len {
				n = state_X_CHECKSUM
			}
		case state_X_CHECKSUM:
			ccrc := inp[i]
			ts_output(mspfh, offset)
			if crc != ccrc {
				fmt.Fprintf(mspfh, "CRC error on %d\n", sc.cmd)
			} else {
				msp_output(mspfh, sc)
			}
			n = state_INIT

		case state_LEN:
			sc.len = uint16(inp[i])
			crc = inp[i]
			n = state_CMD
		case state_CMD:
			sc.cmd = uint16(inp[i])
			crc ^= inp[i]
			if sc.len == 0 {
				n = state_CRC
			} else {
				sc.data = make([]byte, sc.len)
				n = state_DATA
				count = 0
			}
		case state_DATA:
			sc.data[count] = inp[i]
			crc ^= inp[i]
			count++
			if count == sc.len {
				n = state_CRC
			}

		case state_CRC:
			ccrc := inp[i]
			ts_output(mspfh, offset)
			if crc != ccrc {
				fmt.Fprintf(mspfh, "CRC error on %d\n", sc.cmd)
			} else {
				msp_output(mspfh, sc)
			}
			n = state_INIT
		}
	}
}
