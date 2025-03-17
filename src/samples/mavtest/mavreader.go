package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
)

const (
	LOG_RAW = iota
	LOG_V2RAW
	LOG_JSON
)

const (
	S_UNKNOWN = 0 + iota
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
	seed  uint8
}

var mavcrcs = []MavCRCList{{0, 50}, {1, 124}, {2, 137}, {4, 237}, {5, 217},
	{6, 104}, {7, 119}, {8, 117}, {11, 89}, {20, 214},
	{21, 159}, {22, 220}, {23, 168}, {24, 24}, {25, 23},
	{26, 170}, {27, 144}, {28, 67}, {29, 115}, {30, 39},
	{31, 246}, {32, 185}, {33, 104}, {34, 237}, {35, 244},
	{36, 222}, {37, 212}, {38, 9}, {39, 254}, {40, 230},
	{41, 28}, {42, 28}, {43, 132}, {44, 221}, {45, 232},
	{46, 11}, {47, 153}, {48, 41}, {49, 39}, {50, 78},
	{51, 196}, {52, 132}, {54, 15}, {55, 3}, {61, 167},
	{62, 183}, {63, 119}, {64, 191}, {65, 118}, {66, 148},
	{67, 21}, {69, 243}, {70, 124}, {73, 38}, {74, 20},
	{75, 158}, {76, 152}, {77, 143}, {81, 106}, {82, 49},
	{83, 22}, {84, 143}, {85, 140}, {86, 5}, {87, 150},
	{89, 231}, {90, 183}, {91, 63}, {92, 54}, {93, 47},
	{100, 175}, {101, 102}, {102, 158}, {103, 208}, {104, 56},
	{105, 93}, {106, 138}, {107, 108}, {108, 32}, {109, 185},
	{110, 84}, {111, 34}, {112, 174}, {113, 124}, {114, 237},
	{115, 4}, {116, 76}, {117, 128}, {118, 56}, {119, 116},
	{120, 134}, {121, 237}, {122, 203}, {123, 250}, {124, 87},
	{125, 203}, {126, 220}, {127, 25}, {128, 226}, {129, 46},
	{130, 29}, {131, 223}, {132, 85}, {133, 6}, {134, 229},
	{135, 203}, {136, 1}, {137, 195}, {138, 109}, {139, 168},
	{140, 181}, {141, 47}, {142, 72}, {143, 131}, {144, 127},
	{146, 103}, {147, 154}, {148, 178}, {149, 200}, {162, 189},
	{166, 21}, {202, 7}, {203, 85},
	{230, 163}, {231, 105}, {232, 151}, {233, 35}, {234, 150},
	{235, 179}, {241, 90}, {242, 104}, {243, 85}, {244, 95},
	{245, 130}, {246, 184}, {247, 81}, {248, 8}, {249, 204},
	{250, 49}, {251, 170}, {252, 44}, {253, 83}, {254, 46},
	{256, 71}, {257, 131}, {258, 187}, {259, 92}, {260, 146},
	{261, 179}, {262, 12}, {263, 133}, {264, 49}, {265, 26},
	{266, 193}, {267, 35}, {268, 14}, {269, 109}, {270, 59},
	{280, 166}, {281, 0}, {282, 123}, {283, 247}, {284, 99},
	{285, 82}, {286, 62}, {299, 19}, {300, 217}, {301, 243},
	{310, 28}, {311, 95}, {320, 243}, {321, 88}, {322, 243},
	{323, 78}, {324, 132}, {330, 23}, {331, 91}, {332, 236},
	{333, 231}, {334, 135}, {335, 225}, {339, 199}, {340, 99},
	{350, 232}, {360, 11}, {370, 98}, {371, 161}, {373, 192},
	{375, 251}, {380, 232}, {385, 147}, {390, 156}, {395, 231},
	{400, 110}, {401, 183}, {9000, 113}, {12900, 114}, {12901, 254},
	{12902, 49}, {12903, 249}, {12904, 85}, {12905, 49}, {12915, 62},
}

const (
	MAVLINK_MSG_HEARTBEAT           = 0
	MAVLINK_MSG_SYS_STATUS          = 1
	MAVLINK_MSG_GPS_RAW_INT         = 24
	MAVLINK_MSG_SCALED_PRESSURE     = 29
	MAVLINK_MSG_ATTITUDE            = 30
	MAVLINK_MSG_GLOBAL_POSITION_INT = 33
	MAVLINK_MSG_RC_CHANNELS_RAW     = 35
	MAVLINK_MSG_GPS_GLOBAL_ORIGIN   = 49
	MAVLINK_MSG_VFR_HUD             = 74
	MAVLINK_MSG_RADIO_STATUS        = 109
	MAVLINK_MSG_BATTERY_STATUS      = 147
	MAVLINK_MSG_ID_RADIO            = 166
	MAVLINK_MSG_ID_TRAFFIC_REPORT   = 246
	MAVLINK_MSG_STATUSTEXT          = 253
)

type MavMsg struct {
	name   string
	expect byte
}

type MavReader struct {
	state    int
	cmd      uint32
	csize    byte
	needed   byte
	mavsum   uint16
	rxmavsum uint16
	mavsig   int
	m1_ok    int
	m1_fail  int
	m2_ok    int
	m2_fail  int
	ftype    uint8
	payload  []byte
	reader   *bufio.Reader
	mavmeta  map[uint32]MavMsg
	vers     byte
	firstoff float64
	elapsed  float64
	nbytes   uint
}

type V2Header struct {
	Offset float64
	Size   uint16
	Dirn   byte
}

type JSItem struct {
	Stamp    float64 `json:"stamp"`
	Length   uint16  `json:"length"`
	Dirn     byte    `json:"direction"`
	RawBytes []byte  `json:"rawdata"`
}

func lookup(id uint32) uint8 {
	res := uint8(0)
	for _, v := range mavcrcs {
		if v.msgid == id {
			res = v.seed
			break
		}
	}
	return res
}

func mavlink_crc(acc uint16, val uint8) uint16 {
	var tmp uint8
	tmp = val ^ uint8(acc&0xff)
	tmp ^= (tmp << 4)
	acc = acc>>8 ^ uint16(tmp)<<8 ^ uint16(tmp)<<3 ^ uint16(tmp)>>4
	return acc
}

func (m *MavReader) set_reader(rfh io.ReadCloser) error {
	m.reader = bufio.NewReader(rfh)
	sig, err := m.reader.Peek(3)
	if err == nil {
		if sig[0] == 'v' && sig[1] == '2' && sig[2] == '\n' {
			m.reader.Discard(3)
			m.ftype = LOG_V2RAW
		} else if sig[0] == '{' && sig[1] == '"' {
			m.ftype = LOG_JSON
		}
	}
	return err
}

func (m *MavReader) get_data() ([]byte, error) {
	var err error = nil
	var dat []byte
	switch m.ftype {
	case LOG_RAW:
		dat = make([]byte, 128)
		_, err = io.ReadFull(m.reader, dat)
		return dat, err

	case LOG_V2RAW:
		var hdr V2Header
		for err == nil {
			err = binary.Read(m.reader, binary.LittleEndian, &hdr)
			nr := int(hdr.Size)
			if err == nil {
				if hdr.Dirn == 'i' {
					dat = make([]byte, nr)
					_, err = io.ReadFull(m.reader, dat)
					m.elapsed = hdr.Offset
					m.nbytes += uint(hdr.Size)
					return dat, err
				} else {
					_, err = m.reader.Discard(nr)
				}
			}
		}

	case LOG_JSON:
		dat, err = m.reader.ReadBytes('\n')
		if err == nil {
			var js JSItem
			err = json.Unmarshal(dat, &js)
			if err == nil {
				if js.Dirn == 'i' {
					m.elapsed = js.Stamp
					m.nbytes += uint(js.Length)
					return js.RawBytes, err
				}
			}
		}
	}
	return nil, err
}
func (m *MavReader) process(dat []byte) {
	for _, b := range dat {
		switch m.state {
		case S_UNKNOWN:
			if b == 0xfe {
				m.state = S_M_SIZE
				if m.vers == 0 {
					m.firstoff = m.elapsed
				}
				m.vers = 1
			} else if b == 0xfd {
				if m.vers == 0 {
					m.firstoff = m.elapsed
				}
				m.state = S_M2_SIZE
				m.vers = 2
			}
		case S_M_SIZE:
			m.csize = b
			m.needed = b
			m.payload = make([]byte, 256)
			m.mavsum = mavlink_crc(0xffff, m.csize)
			m.state = S_M_SEQ
		case S_M_SEQ:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M_ID1
		case S_M_ID1:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M_ID2
		case S_M_ID2:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M_MSGID
		case S_M_MSGID:
			m.mavsum = mavlink_crc(m.mavsum, b)
			if m.csize == 0 {
				m.state = S_M_CRC1
			} else {
				m.state = S_M_DATA
			}
			m.cmd = uint32(b)
		case S_M_DATA:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.payload[m.csize-m.needed] = b
			m.needed -= 1
			if m.needed == 0 {
				m.state = S_M_CRC1
			}
		case S_M_CRC1:
			var seed = lookup(m.cmd)
			m.mavsum = mavlink_crc(m.mavsum, seed)
			m.rxmavsum = uint16(b)
			m.state = S_M_CRC2
		case S_M_CRC2:
			m.rxmavsum |= (uint16(b) << 8)
			if m.rxmavsum != m.mavsum {
				m.m1_fail += 1
				fmt.Printf("Mav1: CRC Fail, got %x != %x (cmd=%d, len=%d)\n", m.rxmavsum, m.mavsum, m.cmd, m.csize)
			} else {
				m.mav_show() // cmd,payload
				m.m1_ok += 1
			}
			m.state = S_UNKNOWN

		case S_M2_SIZE:
			m.csize = b
			m.needed = b
			m.payload = make([]byte, 256)
			m.mavsum = mavlink_crc(0xffff, uint8(m.csize))
			m.state = S_M2_FLG1

		case S_M2_FLG1:
			m.mavsum = mavlink_crc(m.mavsum, b)
			if (b & 1) == 1 {
				m.mavsig = 13
			} else {
				m.mavsig = 0
			}
			m.state = S_M2_FLG2

		case S_M2_FLG2:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M2_SEQ

		case S_M2_SEQ:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M2_ID1

		case S_M2_ID1:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M2_ID2

		case S_M2_ID2:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M2_MSGID0

		case S_M2_MSGID0:
			m.cmd = uint32(b)
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M2_MSGID1
			break

		case S_M2_MSGID1:
			m.cmd |= (uint32(b) << 8)
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.state = S_M2_MSGID2
			break

		case S_M2_MSGID2:
			m.cmd |= (uint32(b) << 16)
			m.mavsum = mavlink_crc(m.mavsum, b)
			if m.csize == 0 {
				m.state = S_M2_CRC1
			} else {
				m.state = S_M2_DATA
			}

		case S_M2_DATA:
			m.mavsum = mavlink_crc(m.mavsum, b)
			m.payload[m.csize-m.needed] = b
			m.needed -= 1
			if m.needed == 0 {
				m.state = S_M2_CRC1
			}

		case S_M2_CRC1:
			var seed = lookup(m.cmd)
			m.mavsum = mavlink_crc(m.mavsum, seed)
			m.rxmavsum = uint16(b)
			m.state = S_M2_CRC2

		case S_M2_CRC2:
			m.rxmavsum |= (uint16(b) << 8)
			if m.rxmavsum != m.mavsum {
				m.m2_fail += 1
				fmt.Printf("Mav2: CRC Fail, got %x != %x (cmd=%d, len=%d)\n", m.rxmavsum, m.mavsum, m.cmd, m.csize)
				m.state = S_UNKNOWN
			} else {
				m.m2_ok += 1
				if m.csize != 0 {
					m.mav_show()
				}
				if m.mavsig == 0 {
					m.state = S_UNKNOWN
				} else {
					m.state = S_M2_SIG
				}
			}
		case S_M2_SIG:
			m.mavsig -= 1
			if m.mavsig == 0 {
				m.state = S_UNKNOWN
			}
		default:
			m.state = S_UNKNOWN
		}
	}
}

func (m *MavReader) mav_len_check() bool {
	mm, ok := m.mavmeta[m.cmd]
	if ok {
		fmt.Printf("%07.2f ", m.elapsed)
		fmt.Printf("Mav%d: %s %d", m.vers, mm.name, m.csize)
		if m.csize > mm.expect {
			fmt.Printf("!%d", mm.expect)
		} else if m.csize < mm.expect {
			for j := m.csize; j < mm.expect; j++ {
				m.payload[j] = 0
			}
			fmt.Printf("/%d", mm.expect)
		}
		fmt.Print(" : ")
		return true
	} else {
		return false
	}
}

func (m *MavReader) mav_show() {

	if m.mav_len_check() {
		switch m.cmd {
		case MAVLINK_MSG_HEARTBEAT: // heartbeat
			fmt.Printf("Heartbeat: t: %d a: %d b: %d s: %d m: %d\n", m.payload[4], m.payload[5], m.payload[6], m.payload[7], m.payload[8])

		case MAVLINK_MSG_SYS_STATUS: // sys_status
			fmt.Printf("Status: l: %d v: %d c: %d\n",
				binary.LittleEndian.Uint16(m.payload[12:14]),
				binary.LittleEndian.Uint16(m.payload[14:16]),
				int(binary.LittleEndian.Uint16(m.payload[16:18])))

		case MAVLINK_MSG_GPS_RAW_INT: // gps_raw_int
			var hdg uint16
			hdg = binary.LittleEndian.Uint16(m.payload[26:28])
			fmt.Printf("GPS: la: %.7f lo: %.7f",
				float64(int32(binary.LittleEndian.Uint32(m.payload[8:12])))/1e7,
				float64(int32(binary.LittleEndian.Uint32(m.payload[12:16])))/1e7)
			if hdg != 65535 {
				hdg /= 100
				fmt.Printf(" cog: %v", hdg)
			}

			var alt int32
			alt = int32(binary.LittleEndian.Uint32(m.payload[16:20]))
			fmt.Printf(" alt (msl,mm): %v", alt)
			fmt.Println()

		case MAVLINK_MSG_SCALED_PRESSURE: // scaled_pressure
			var it uint32
			var pa, pr float32
			var itemp int16
			buf := bytes.NewReader(m.payload)
			binary.Read(buf, binary.LittleEndian, &it)
			binary.Read(buf, binary.LittleEndian, &pa)
			binary.Read(buf, binary.LittleEndian, &pr)
			binary.Read(buf, binary.LittleEndian, &itemp)
			fmt.Printf("Pressure: t: %d %.1f t°: %d\n", it, pa, itemp)

		case MAVLINK_MSG_ATTITUDE: // attitude
			var it uint32
			var r, p, y float32
			buf := bytes.NewReader(m.payload)
			binary.Read(buf, binary.LittleEndian, &it)
			binary.Read(buf, binary.LittleEndian, &r)
			binary.Read(buf, binary.LittleEndian, &p)
			binary.Read(buf, binary.LittleEndian, &y)
			r *= 57.29578
			p *= 57.29578
			y *= 57.29578
			if y < 0 {
				y += 360
			}
			fmt.Printf("Attitude: t: %d r: %.1f p: %.1f y: %.1f\n", it, r, p, y)

		case MAVLINK_MSG_GLOBAL_POSITION_INT:
			var hdg uint16
			hdg = binary.LittleEndian.Uint16(m.payload[26:28])
			fmt.Printf("Gbl Pos: la: %.7f lo: %.7f alt (msl,mm): %v alt (baro,mm): %v  ",
				float64(int32(binary.LittleEndian.Uint32(m.payload[4:8])))/1e7,
				float64(int32(binary.LittleEndian.Uint32(m.payload[8:12])))/1e7,
				int32(binary.LittleEndian.Uint32(m.payload[12:16])),
				int32(binary.LittleEndian.Uint32(m.payload[16:20])))
			if hdg != 65535 {
				hdg /= 100
				fmt.Printf(" hdg: %v", hdg)
			}
			fmt.Println()

		case MAVLINK_MSG_RC_CHANNELS_RAW: // rc_channels_raw
			fmt.Printf("RC Chan t: %d 1: %d 2: %d 3: %d 4: %d r: %d\n",
				binary.LittleEndian.Uint32(m.payload[0:4]),
				binary.LittleEndian.Uint16(m.payload[4:6]),
				binary.LittleEndian.Uint16(m.payload[6:8]),
				binary.LittleEndian.Uint16(m.payload[8:10]),
				binary.LittleEndian.Uint16(m.payload[10:12]),
				m.payload[21])

		case MAVLINK_MSG_GPS_GLOBAL_ORIGIN:
			fmt.Printf("Origin: la: %.7f lo: %.7f alt (msl,mm): %d\n",
				float64(int32(binary.LittleEndian.Uint32(m.payload[0:4])))/1e7,
				float64(int32(binary.LittleEndian.Uint32(m.payload[4:8])))/1e7,
				int32(binary.LittleEndian.Uint32(m.payload[8:12])))

		case MAVLINK_MSG_VFR_HUD: // vfr_hud
			var as, gs, alt, climb float32
			var hd, th uint16
			buf := bytes.NewReader(m.payload)
			binary.Read(buf, binary.LittleEndian, &as)
			binary.Read(buf, binary.LittleEndian, &gs)
			binary.Read(buf, binary.LittleEndian, &alt)
			binary.Read(buf, binary.LittleEndian, &climb)
			binary.Read(buf, binary.LittleEndian, &hd)
			binary.Read(buf, binary.LittleEndian, &th)
			fmt.Printf("vfr hud a: %.1f g: %.1f h: %d thr: %d a: %.1f cl: %.1f\n", as, gs, hd, th, alt, climb)

		case MAVLINK_MSG_RADIO_STATUS, MAVLINK_MSG_ID_RADIO: // radio_statusx1
			fmt.Printf("Radio rssi: %d rem: %d\n", m.payload[4], m.payload[5])

		case MAVLINK_MSG_BATTERY_STATUS: // battery_status
			fmt.Printf("Bat Status: c: %d v0-4: %d %d %d %d\n",
				int(binary.LittleEndian.Uint32(m.payload[0:4])),
				int16(binary.LittleEndian.Uint16(m.payload[10:12])),
				int16(binary.LittleEndian.Uint16(m.payload[12:14])),
				int16(binary.LittleEndian.Uint16(m.payload[14:16])),
				int16(binary.LittleEndian.Uint16(m.payload[16:18])))

		case MAVLINK_MSG_STATUSTEXT: // statustext
			str := strings.TrimSpace(string(m.payload[1:51]))
			fmt.Printf("status: s: %d t: %s\n", m.payload[0], str)

		case MAVLINK_MSG_ID_TRAFFIC_REPORT:
			var valid uint16
			var icao uint32
			var callsign string
			icao = binary.LittleEndian.Uint32(m.payload[0:4])
			valid = binary.LittleEndian.Uint16(m.payload[22:24])
			if (valid & 0x10) == 0x10 {
				var cs []byte
				for j := 0; j < 9; j++ {
					if m.payload[27+j] != ' ' && m.payload[27+j] != 0 {
						cs = append(cs, m.payload[27+j])
					}
				}
				callsign = string(cs)
			} else {
				callsign = "unknown"
			}

			fmt.Printf("ICAO %x, callsign %s valid %x : ", icao, callsign, valid)
			if (valid & 0x1) == 1 {
				ilat := int32(binary.LittleEndian.Uint32(m.payload[4:8]))
				lat := float64(ilat) / 1e7
				ilon := int32(binary.LittleEndian.Uint32(m.payload[8:12]))
				lon := float64(ilon) / 1e7
				fmt.Printf("%f %f ", lat, lon)
			}
			if (valid & 0x2) == 2 {
				ialt := int32(binary.LittleEndian.Uint32(m.payload[12:16]))
				alt := float64(ialt) / 1e3
				fmt.Printf("%.1fm ", alt)
			}
			if (valid & 0x4) == 4 {
				icse := binary.LittleEndian.Uint16(m.payload[16:18])
				cse := float64(icse) / 1e2
				fmt.Printf("%.0f° ", cse)
			}
			if (valid & 0x8) == 8 {
				ivel := binary.LittleEndian.Uint16(m.payload[16:18])
				hvel := float64(ivel) / 1e2
				fmt.Printf("%.0fm/s ", hvel)
			}
			squawk := binary.LittleEndian.Uint16(m.payload[24:26])
			if squawk != 0xffff {
				fmt.Printf("swk=%x ", squawk)
			}
			// time since last communication (seconds)
			fmt.Printf("etyp %x, tslc %d\n", m.payload[36], m.payload[37])

		default:
			fmt.Printf("** Unhandled **\n")
		}
	} else {
		fmt.Printf("Mav%d: Unrecognised %d %d\n", m.vers, m.cmd, m.csize)
	}
}

func (m *MavReader) load_meta() {
	m.mavmeta = map[uint32]MavMsg{
		MAVLINK_MSG_HEARTBEAT:           {"mavlink_msg_heartbeat", 9},
		MAVLINK_MSG_SYS_STATUS:          {"mavlink_msg_sys_status", 31},
		MAVLINK_MSG_GPS_RAW_INT:         {"mavlink_msg_gps_raw_int", 52},
		MAVLINK_MSG_SCALED_PRESSURE:     {"mavlink_msg_scaled_pressure", 16},
		MAVLINK_MSG_ATTITUDE:            {"mavlink_msg_attitude", 28},
		MAVLINK_MSG_GLOBAL_POSITION_INT: {"mavlink_msg_global_position_int", 28},
		MAVLINK_MSG_RC_CHANNELS_RAW:     {"mavlink_msg_rc_channels_raw", 22},
		MAVLINK_MSG_GPS_GLOBAL_ORIGIN:   {"mavlink_msg_gps_global_origin", 16},
		MAVLINK_MSG_VFR_HUD:             {"mavlink_msg_vfr_hud", 20},
		MAVLINK_MSG_RADIO_STATUS:        {"mavlink_msg_radio_status", 9},
		MAVLINK_MSG_ID_RADIO:            {"mavlink_msg_id_radio", 9},
		MAVLINK_MSG_BATTERY_STATUS:      {"mavlink_msg_battery_status", 54},
		MAVLINK_MSG_STATUSTEXT:          {"mavlink_msg_statustext", 54},
		MAVLINK_MSG_ID_TRAFFIC_REPORT:   {"mavlink_traffic_report", 38},
	}
}

func main() {
	if len(os.Args) > 1 {
		rfh, err := os.Open(os.Args[1])
		if err == nil {
			defer rfh.Close()
			m := MavReader{}
			m.load_meta()
			err := m.set_reader(rfh)
			if err == nil {
				for {
					dat, err := m.get_data()
					if err == nil {
						m.process(dat)
					} else {
						break
					}
				}

				if m.m1_ok+m.m1_fail > 0 {
					fmt.Printf("V1 OK %d, fail %d\n", m.m1_ok, m.m1_fail)
				}
				if m.m2_ok+m.m2_fail > 0 {
					fmt.Printf("V2 OK %d, fail %d\n", m.m2_ok, m.m2_fail)
				}
				m.elapsed -= m.firstoff
				if m.elapsed > 0 {
					nmsg := m.m1_ok + m.m1_fail + m.m2_ok + m.m2_fail
					fmt.Printf("%d bytes, %d messages in %.1fsec\n", m.nbytes, nmsg, m.elapsed)
					fmt.Printf("%.0f messages/sec, %.0f bytes/sec\n", float64(nmsg)/m.elapsed, float64(m.nbytes)/m.elapsed)
				}
			}
		} else {
			fmt.Fprintf(os.Stderr, "File %v\n", err)
		}
	} else {
		fmt.Fprintf(os.Stderr, "Need a file\n")
	}
}
