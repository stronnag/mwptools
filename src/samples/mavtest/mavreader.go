package main

import (
	"fmt"
	"os"
	"encoding/binary"
	"bytes"
	"strings"
)

const (
	S_UNKNOWN = iota
	S_M_STX
	S_M_SIZE
	S_M_SEQ
	S_M_ID1
	S_M_ID2
	S_M_MSGID
	S_M_DATA
	S_M_CRC1
	S_M_CRC2
	S_M2_STX
	S_M2_SIZE
	S_M2_FLG1
	S_M2_FLG2
	S_M2_SEQ
	S_M2_ID1
	S_M2_ID2
	S_M2_MSGID0
	S_M2_MSGID1
	S_M2_MSGID2
	S_M2_DATA
	S_M2_CRC1
	S_M2_CRC2
	S_M2_SIG
)

type MavCRCList struct {
	msgid uint32
	seed uint8
}

var mavcrcs =  [] MavCRCList{
	{ 0, 50 }, { 1, 124 }, { 2, 137 }, { 4, 237 }, { 5, 217 },
	{ 6, 104 }, { 7, 119 }, { 8, 117 }, { 11, 89 }, { 20, 214 },
	{ 21, 159 }, { 22, 220 }, { 23, 168 }, { 24, 24 }, { 25, 23 },
	{ 26, 170 }, { 27, 144 }, { 28, 67 }, { 29, 115 }, { 30, 39 },
	{ 31, 246 }, { 32, 185 }, { 33, 104 }, { 34, 237 }, { 35, 244 },
	{ 36, 222 }, { 37, 212 }, { 38, 9 }, { 39, 254 }, { 40, 230 },
	{ 41, 28 }, { 42, 28 }, { 43, 132 }, { 44, 221 }, { 45, 232 },
	{ 46, 11 }, { 47, 153 }, { 48, 41 }, { 49, 39 }, { 50, 78 },
	{ 51, 196 }, { 52, 132 }, { 54, 15 }, { 55, 3 }, { 61, 167 },
	{ 62, 183 }, { 63, 119 }, { 64, 191 }, { 65, 118 }, { 66, 148 },
	{ 67, 21 }, { 69, 243 }, { 70, 124 }, { 73, 38 }, { 74, 20 },
	{ 75, 158 }, { 76, 152 }, { 77, 143 }, { 81, 106 }, { 82, 49 },
	{ 83, 22 }, { 84, 143 }, { 85, 140 }, { 86, 5 }, { 87, 150 },
	{ 89, 231 }, { 90, 183 }, { 91, 63 }, { 92, 54 }, { 93, 47 },
	{ 100, 175 }, { 101, 102 }, { 102, 158 }, { 103, 208 }, { 104, 56 },
	{ 105, 93 }, { 106, 138 }, { 107, 108 }, { 108, 32 }, { 109, 185 },
	{ 110, 84 }, { 111, 34 }, { 112, 174 }, { 113, 124 }, { 114, 237 },
	{ 115, 4 }, { 116, 76 }, { 117, 128 }, { 118, 56 }, { 119, 116 },
	{ 120, 134 }, { 121, 237 }, { 122, 203 }, { 123, 250 }, { 124, 87 },
	{ 125, 203 }, { 126, 220 }, { 127, 25 }, { 128, 226 }, { 129, 46 },
	{ 130, 29 }, { 131, 223 }, { 132, 85 }, { 133, 6 }, { 134, 229 },
	{ 135, 203 }, { 136, 1 }, { 137, 195 }, { 138, 109 }, { 139, 168 },
	{ 140, 181 }, { 141, 47 }, { 142, 72 }, { 143, 131 }, { 144, 127 },
	{ 146, 103 }, { 147, 154 }, { 148, 178 }, { 149, 200 }, { 162, 189 },
	{ 230, 163 }, { 231, 105 }, { 232, 151 }, { 233, 35 }, { 234, 150 },
	{ 235, 179 }, { 241, 90 }, { 242, 104 }, { 243, 85 }, { 244, 95 },
	{ 245, 130 }, { 246, 184 }, { 247, 81 }, { 248, 8 }, { 249, 204 },
	{ 250, 49 }, { 251, 170 }, { 252, 44 }, { 253, 83 }, { 254, 46 },
	{ 256, 71 }, { 257, 131 }, { 258, 187 }, { 259, 92 }, { 260, 146 },
	{ 261, 179 }, { 262, 12 }, { 263, 133 }, { 264, 49 }, { 265, 26 },
	{ 266, 193 }, { 267, 35 }, { 268, 14 }, { 269, 109 }, { 270, 59 },
	{ 280, 166 }, { 281, 0 }, { 282, 123 }, { 283, 247 }, { 284, 99 },
	{ 285, 82 }, { 286, 62 }, { 299, 19 }, { 300, 217 }, { 301, 243 },
	{ 310, 28 }, { 311, 95 }, { 320, 243 }, { 321, 88 }, { 322, 243 },
	{ 323, 78 }, { 324, 132 }, { 330, 23 }, { 331, 91 }, { 332, 236 },
	{ 333, 231 }, { 334, 135 }, { 335, 225 }, { 339, 199 }, { 340, 99 },
	{ 350, 232 }, { 360, 11 }, { 370, 98 }, { 371, 161 }, { 373, 192 },
		{ 375, 251 }, { 380, 232 }, { 385, 147 }, { 390, 156 }, { 395, 231 },
	{ 400, 110 }, { 401, 183 }, { 9000, 113 }, { 12900, 114 }, { 12901, 254 },
	{ 12902, 49 }, { 12903, 249 }, { 12904, 85 }, { 12905, 49 }, { 12915, 62 },
}

func retrieve_mav(filename string) ([]byte, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	stats, statsErr := file.Stat()
	if statsErr != nil {
		return nil, statsErr
	}
	var size int64 = stats.Size()
	bytes := make([]byte, size)
	_, err = file.Read(bytes)
	return bytes, err
}

func lookup(id uint32) uint8 {
	res := uint8(0)
	for _, v := range(mavcrcs) {
		if v.msgid == id {
			res = v.seed
			break;
		}
	}
	return res;
}

func mavlink_crc(acc uint16, val uint8) (uint16) {
	var tmp uint8
	tmp = val ^ uint8(acc&0xff)
	tmp ^= (tmp<<4)
	acc = acc>>8 ^ uint16(tmp)<<8 ^ uint16(tmp)<<3 ^ uint16(tmp)>>4
	return acc
}

func main() {
	if len(os.Args) > 1 {
		if dat, err := retrieve_mav(os.Args[1]); err == nil {
			state := S_UNKNOWN
			cmd := uint32(0)
			csize := byte(0)
			needed := byte(0)
			mavsum := uint16(0)
			rxmavsum := uint16(0)
			mavsig := 0
			m1_ok := 0
			m1_fail := 0
			m2_ok := 0
			m2_fail := 0
			m_offset := 0
			for n, b := range dat {
				switch state {
				case S_UNKNOWN:
					m_offset = 0
					if b == 0xfe {
						state = S_M_SIZE
					} else if b == 0xfd {
						state = S_M2_SIZE
					}
				case S_M_SIZE:
					csize = b
					needed = b
					mavsum = mavlink_crc(0xffff, csize)
					state = S_M_SEQ
				case S_M_SEQ:
					mavsum = mavlink_crc(mavsum, b)
					state = S_M_ID1
				case S_M_ID1:
					mavsum = mavlink_crc(mavsum, b)
					state = S_M_ID2
				case S_M_ID2:
					mavsum = mavlink_crc(mavsum, b)
					state = S_M_MSGID
				case S_M_MSGID:
					mavsum = mavlink_crc(mavsum, b)
					if csize == 0 {
						state = S_M_CRC1
					} else {
						state = S_M_DATA
						m_offset = n + 1
					}
					cmd = uint32(b)
				case S_M_DATA:
					mavsum = mavlink_crc(mavsum, b)
					needed -= 1
					if needed == 0 {
						state = S_M_CRC1
					}
				case S_M_CRC1:
					var seed  = lookup(cmd)
					mavsum = mavlink_crc(mavsum, seed)
					rxmavsum = uint16(b)
					state = S_M_CRC2
				case S_M_CRC2:
					rxmavsum |= (uint16(b) << 8)
					if rxmavsum != mavsum {
						m1_fail += 1
						fmt.Fprintf(os.Stderr, "MAV v1 CRC Fail, got %x != %x (cmd=%d, len=%d)\n", rxmavsum, mavsum, cmd, csize)
					} else {
						m_end := m_offset+int(csize)
						if m_end <= len(dat) {
							mav_show(1, cmd, dat[m_offset:m_end])
						}
						m1_ok += 1
					}
					state = S_UNKNOWN

				case S_M2_SIZE:
					csize = b
					needed = b
					mavsum = mavlink_crc(0xffff, uint8(csize))
					state = S_M2_FLG1

				case S_M2_FLG1:
					mavsum = mavlink_crc(mavsum, b)
					if((b & 1) == 1) {
						mavsig = 13
					}	else {
						mavsig = 0
					}
					state = S_M2_FLG2

				case S_M2_FLG2:
					mavsum = mavlink_crc(mavsum, b)
					state = S_M2_SEQ

				case S_M2_SEQ:
					mavsum = mavlink_crc(mavsum, b)
					state = S_M2_ID1

				case S_M2_ID1:
					mavsum = mavlink_crc(mavsum, b)
					state = S_M2_ID2

				case S_M2_ID2:
					mavsum = mavlink_crc(mavsum, b)
					state = S_M2_MSGID0

				case S_M2_MSGID0:
					cmd = uint32(b)
					mavsum = mavlink_crc(mavsum, b)
					state = S_M2_MSGID1
					break

				case S_M2_MSGID1:
					cmd |= uint32(b << 8)
					mavsum = mavlink_crc(mavsum, b)
					state = S_M2_MSGID2
					break

				case S_M2_MSGID2:
					cmd |= uint32(b << 16)
					mavsum = mavlink_crc(mavsum, b)
					if csize == 0 {
						state = S_M2_CRC1
					} else {
						state = S_M2_DATA
						m_offset = n + 1
					}

				case S_M2_DATA:
					mavsum = mavlink_crc(mavsum, b)
					needed -= 1
					if needed == 0 {
						state = S_M2_CRC1
					}

				case S_M2_CRC1:
					var seed  = lookup(cmd)
					mavsum = mavlink_crc(mavsum, seed)
					rxmavsum = uint16(b)
					state = S_M2_CRC2

				case S_M2_CRC2:
					rxmavsum |= (uint16(b) << 8)
					if rxmavsum != mavsum {
						m2_fail += 1
						fmt.Fprintf(os.Stderr, "MAV 2 CRC Fail, got %x != %x (cmd=%d, len=%d)\n", rxmavsum, mavsum, cmd, csize)
						state = S_UNKNOWN
					} else {
						m2_ok += 1
						if csize != 0 {
							m_end := m_offset+int(csize)
							if m_end <= len(dat) {
								mav_show(2, cmd, dat[m_offset:m_offset+int(csize)])
							}
						}
						if mavsig == 0 {
							state = S_UNKNOWN
						} else {
							state = S_M2_SIG
						}
					}
				case S_M2_SIG:
					mavsig -= 1
					if  mavsig == 0 {
						state = S_UNKNOWN
					}
				default:
					state = S_UNKNOWN
				}
			}
			if m1_ok + m1_fail > 0 {
				fmt.Printf("V1 OK %d, fail %d\n", m1_ok, m1_fail)
			}
			if m2_ok + m2_fail > 0 {
				fmt.Printf("V2 OK %d, fail %d\n", m2_ok, m2_fail)
			}
		}
	}
}

func mav_show(vers int, cmd uint32, payload []byte) {
	fmt.Printf("Mav%d: %d %d : ", vers, cmd, len(payload))
	lpay := len(payload)
	var expect int
	switch cmd {
	case 0: // heartbeat
		expect = 9
		if lpay <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			fmt.Printf("Heartbeat: t: %d a: %d b: %d s: %d m: %d\n", b[4],b[5],b[6],b[7],b[8])
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	case 1: // sys_status
		expect = 31
		if len(payload) <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			fmt.Printf("Status: l: %d v: %d c: %d\n",
				binary.LittleEndian.Uint16(b[12:14]),
				binary.LittleEndian.Uint16(b[14:16]),
				int(binary.LittleEndian.Uint16(b[16:18])))
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	case 24: // gps_raw_int
		expect = 52
		if len(payload) <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			fmt.Printf("GPS: la: %d lo: %d\n",
				int(binary.LittleEndian.Uint32(b[8:12])),
				int(binary.LittleEndian.Uint32(b[12:16])))

		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	case 29: // scaled_pressure
		expect = 16
		if lpay <= expect {
			var it uint32
			var pa,pr float32
			var itemp int16
			b := make([]byte, expect)
			copy(b, payload)
			buf := bytes.NewReader(b)
			binary.Read(buf, binary.LittleEndian, &it)
			binary.Read(buf, binary.LittleEndian, &pa)
			binary.Read(buf, binary.LittleEndian, &pr)
			binary.Read(buf, binary.LittleEndian, &itemp)
			fmt.Printf("Pressure: t: %d %.1f t°: %d\n", it, pa, itemp)
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	case 30: // attitude
		expect = 28
		if lpay <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			var it uint32
			var r,p,y float32
			buf := bytes.NewReader(b)
			binary.Read(buf, binary.LittleEndian, &it)
			binary.Read(buf, binary.LittleEndian, &r)
			binary.Read(buf, binary.LittleEndian, &p)
			binary.Read(buf, binary.LittleEndian, &y)
			fmt.Printf("Attitude: t: %d r: %.1f p: %.1f y: %.1f\n", it, r, p, y)
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}
	case 35: // rc_channels_raw
		expect = 22
		if len(payload) <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			fmt.Printf("RC Chan t: %d 1: %d 2: %d 3: %d 4: %d r: %d\n",
				binary.LittleEndian.Uint32(b[0:4]),
				binary.LittleEndian.Uint16(b[4:6]),
				binary.LittleEndian.Uint16(b[6:8]),
				binary.LittleEndian.Uint16(b[8:10]),
				binary.LittleEndian.Uint16(b[10:12]),
				b[21])
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}
	case 51:
		expect = 5
		if len(payload) <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			fmt.Println()
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	case 74: // vfr_hud
		expect = 20
		if len(payload) <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			var as, gs, alt, climb float32
			var hd,th uint16
			buf := bytes.NewReader(b)
			binary.Read(buf, binary.LittleEndian, &as)
			binary.Read(buf, binary.LittleEndian, &gs)
			binary.Read(buf, binary.LittleEndian, &alt)
			binary.Read(buf, binary.LittleEndian, &climb)
			binary.Read(buf, binary.LittleEndian, &hd)
			binary.Read(buf, binary.LittleEndian, &th)
			fmt.Printf("vfr hud a: %.1f g: %.1f h: %d thr: %d a: %.1f cl: %.1f\n",
				as,gs,hd,th,alt,climb)
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	case 109: // radio_statusx1
		expect = 9
		if len(payload) <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			fmt.Printf("Radio rssi: %d rem: %d\n", b[4], b[5])
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	case 147: // battery_status
		expect = 54
		if len(payload) <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			fmt.Printf("Bat Status: c: %d v0-4: %d %d %d %d\n",
				int(binary.LittleEndian.Uint32(b[0:4])),
				int16(binary.LittleEndian.Uint16(b[10:12])),
				int16(binary.LittleEndian.Uint16(b[12:14])),
				int16(binary.LittleEndian.Uint16(b[14:16])),
				int16(binary.LittleEndian.Uint16(b[16:18])))
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	case 253: // statustext
		expect = 54
		if len(payload) <= expect {
			b := make([]byte, expect)
			copy(b, payload)
			str := strings.TrimSpace(string(payload[1:51]))
			fmt.Printf("status: s: %d t: %s\n", payload[0], str)
		} else {
			fmt.Printf("mav #%d len error %d, expected %d\n", cmd, lpay, expect)
		}

	}
}
