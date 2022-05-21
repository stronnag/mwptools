package main

import (
	"encoding/binary"
	"fmt"
	"go.bug.st/serial"
	"go.bug.st/serial/enumerator"
	"log"
	"os"
)

const (
	msp_FC_VARIANT        = 2
	msp_FC_VERSION        = 3
	msp_DATAFLASH_SUMMARY = 70
	msp_DATAFLASH_READ    = 71
	msp_DATAFLASH_ERASE   = 72
	msp_BLACKBOX_CONFIG   = 80
	msp_BLACKBOX_CONFIGv2 = 0x201A
	msp_QUIT              = 0x7fff
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

type SerDev interface {
	Read(buf []byte) (int, error)
	Write(buf []byte) (int, error)
	Close() error
}

type MSPSerial struct {
	SerDev
}

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

func (p *MSPSerial) msp_reader(c0 chan SChan) {
	inp := make([]byte, 5000)
	var count = uint16(0)
	var crc = byte(0)
	var sc SChan

	n := state_INIT
	for {
		nb, err := p.Read(inp)
		if err == nil && nb > 0 {
			for i := 0; i < nb; i++ {
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
						n = state_DIRN
					} else if inp[i] == 'X' {
						n = state_X_HEADER2
					} else {
						n = state_INIT
					}
				case state_DIRN:
					if inp[i] == '!' {
						n = state_LEN
					} else if inp[i] == '>' {
						n = state_LEN
						sc.ok = true
					} else {
						n = state_INIT
					}

				case state_X_HEADER2:
					if inp[i] == '!' {
						n = state_X_FLAGS
					} else if inp[i] == '>' {
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
					if crc != ccrc {
						fmt.Fprintf(os.Stderr, "CRC error on %d\n", sc.cmd)
					} else {
						c0 <- sc
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
					if crc != ccrc {
						fmt.Fprintf(os.Stderr, "CRC error on %d\n", sc.cmd)
					} else {
						c0 <- sc
					}
					n = state_INIT
				}
			}
		} else {
			p.Close()
			if err != nil {
				fmt.Fprintf(os.Stderr, "Read error: %v\n", err)
				sc.len = 0
				sc.ok = false
				sc.cmd = msp_QUIT
				c0 <- sc
				return
			}
		}
	}
}

func encode_mspv1(cmd byte, payload []byte) []byte {
	var paylen byte
	if len(payload) > 0 {
		paylen = byte(len(payload))
	}
	buf := make([]byte, 6+paylen)
	buf[0] = '$'
	buf[1] = 'M'
	buf[2] = '<'
	buf[3] = paylen
	buf[4] = cmd
	if paylen > 0 {
		copy(buf[5:], payload)
	}
	crc := byte(0)
	for _, b := range buf[3:] {
		crc ^= b
	}
	buf[5+paylen] = crc
	return buf
}

func encode_msp(cmd uint16, payload []byte) []byte {
	var paylen int16
	if len(payload) > 0 {
		paylen = int16(len(payload))
	}
	buf := make([]byte, 9+paylen)
	buf[0] = '$'
	buf[1] = 'X'
	buf[2] = '<'
	buf[3] = 0 // flags
	binary.LittleEndian.PutUint16(buf[4:6], cmd)
	binary.LittleEndian.PutUint16(buf[6:8], uint16(paylen))
	if paylen > 0 {
		copy(buf[8:], payload)
	}
	crc := byte(0)
	for _, b := range buf[3 : paylen+8] {
		crc = crc8_dvb_s2(crc, b)
	}
	buf[8+paylen] = crc
	return buf
}

func (p *MSPSerial) MSPVersion() {
	rb := encode_msp(msp_FC_VERSION, nil)
	p.Write(rb)
}

func (p *MSPSerial) MSPVariant() {
	rb := encode_msp(msp_FC_VARIANT, nil)
	p.Write(rb)
}

func (p *MSPSerial) MSPBBLConfig() {
	rb := encode_msp(msp_BLACKBOX_CONFIG, nil)
	p.Write(rb)
}

func (p *MSPSerial) MSPBlackboxConfigV2() {
	rb := encode_msp(msp_BLACKBOX_CONFIGv2, nil)
	p.Write(rb)
}

func (p *MSPSerial) MSPDataFlashErase() {
	rb := encode_msp(msp_DATAFLASH_ERASE, nil)
	p.Write(rb)
}

func (p *MSPSerial) MSPDataFlashSummary() {
	rb := encode_msp(msp_DATAFLASH_SUMMARY, nil)
	p.Write(rb)
}

func (p *MSPSerial) Data_read(addr uint32, needed uint16) {
	msg := make([]byte, 6)
	binary.LittleEndian.PutUint32(msg[0:4], addr)
	binary.LittleEndian.PutUint16(msg[4:6], needed)
	rb := encode_msp(msp_DATAFLASH_READ, msg)
	p.Write(rb)
}

func NewMSPSerial(name string) *MSPSerial {
	mode := &serial.Mode{
		BaudRate: 115200,
	}

	if name[2] == ':' && len(name) == 17 {
		bt := NewBT(name)
		return &MSPSerial{bt}
	} else {
		p, err := serial.Open(name, mode)
		if err != nil {
			log.Fatal(err)
		}
		return &MSPSerial{p}
	}
}

func (m *MSPSerial) Init(c0 chan SChan) {
	go m.msp_reader(c0)
	m.MSPVariant()
}

func (m *MSPSerial) MSPClose() {
	m.Close()
}

func Enumerate_ports() string {
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
