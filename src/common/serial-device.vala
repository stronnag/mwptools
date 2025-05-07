/*
  * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
  *
  * This program is free software; you can redistribute it and/or
  * modify it under the terms of the GNU General Public License
  * as published by the Free Software Foundation; either version 3
  * of the License, or (at your option) any later version.
  *
  * This program is distributed in the hope that it will be useful,
  * but WITHOUT ANY WARRANTY; without even the implied warranty of
  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  * GNU General Public License for more details.
  *
  * You should have received a copy of the GNU General Public License
  * along with this program; if not, write to the Free Software
  * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
  */

 public struct SerialStats {
	 double elapsed;
	 ulong rxbytes;
	 ulong txbytes;
	 double rxrate;
	 double txrate;
	 ulong  msgs;
 }

 namespace SportDev {
	 public enum FrID {
		 ALT_ID = 0x0100,
		 VARIO_ID = 0x0110,
		 CURR_ID = 0x0200,
		 VFAS_ID = 0x0210,
		 CELLS_ID = 0x0300,
		 T1_ID = 0x0400,
		 T2_ID = 0x0410,
		 RPM_ID = 0x0500,
		 FUEL_ID = 0x0600,
		 ACCX_ID = 0x0700,
		 ACCY_ID = 0x0710,
		 ACCZ_ID = 0x0720,
		 GPS_LONG_LATI_ID = 0x0800,
		 GPS_ALT_ID = 0x0820,
		 GPS_SPEED_ID = 0x0830,
		 GPS_COURS_ID = 0x0840,
		 GPS_TIME_DATE_ID = 0x0850,
		 A3_ID = 0x0900,
		 A4_ID = 0x0910,
		 AIR_SPEED_ID = 0x0a00,
		 RBOX_BATT1_ID = 0x0b00,
		 RBOX_BATT2_ID = 0x0b10,
		 RBOX_STATE_ID = 0x0b20,
		 RBOX_CNSP_ID = 0x0b30,
		 DIY_ID = 0x5000,
		 DIY_STREAM_ID = 0x5000,
		 RSSI_ID = 0xf101,
		 ADC1_ID = 0xf102,
		 ADC2_ID = 0xf103,
		 SP2UART_A_ID = 0xfd00,
		 SP2UART_B_ID = 0xfd01,
		 BATT_ID = 0xf104,
		 SWR_ID = 0xf105,
		 XJT_VERSION_ID = 0xf106,
		 FUEL_QTY_ID = 0x0a10,
		 PITCH      = 0x0430 ,
		 ROLL       = 0x0440 ,
		 HOME_DIST  = 0x0420,
		 MODES      = 0x0470,
		 GNSS       = 0x0480,
	 }

	 private enum FrProto {
		 P_START = 0x7e,
		 P_STUFF = 0x7d,
		 P_MASK  = 0x20,
		 P_SIZE = 10
	 }

	 public enum FrStatus {
		 OK = 0,
		 SHORT = 1,
		 CRC = 2,
		 SIZE = 3,
		 PUBLISH = 4
	 }

	 private uint8 buf[64];
	 private bool stuffed = false;
	 private uint8 nb = 0;

	 public uint8[] get_buffer() {
		 return buf;
	 }

	 private bool fr_checksum(uint8[] buf) {
		 uint16 crc = 0;
		 foreach (var b in buf[1:9]) {
			 crc += b;
			 crc += crc >> 8;
			 crc &= 0xff;
		 }
		 return (crc == 0xff);
	 }

	 public FrStatus extract_messages(uint8 b) {
		 FrStatus status = FrStatus.OK;
		 if (b == FrProto.P_START && nb > 0) {
			 if (nb == FrProto.P_SIZE) {
				 nb = 1; // leave the 0x7e in the buffer ...
				 return FrStatus.PUBLISH;
			 } else {
				 if(nb > 3) {
					 status = FrStatus.SHORT;
				 }
				 nb = 0;
			 }
		 }
		 if (stuffed) {
			 b = b ^ FrProto.P_MASK;
			 stuffed = false;
		 }
		 else if (b == FrProto.P_STUFF) {
			 stuffed = true;
		 }

		 if(status == FrStatus.OK) {
			 buf[nb] = b;
			 nb++;
			 if (nb > FrProto.P_SIZE) {
				 nb = 0;
				 status = FrStatus.SIZE;
			 }
		 } else {
			 nb = 0;
		 }
		 return status;
	 }
 }

 namespace MavSize {
	 struct MSize {
		 uint32 msgid;
		 uint32 size;
	 }
	 const MSize[] sizes = {
		 {Msp.Cmds.MAVLINK_MSG_ID_HEARTBEAT, 9},
		 {Msp.Cmds.MAVLINK_MSG_ID_SYS_STATUS, 31},
		 {Msp.Cmds.MAVLINK_MSG_GPS_RAW_INT, 52},
		 {Msp.Cmds.MAVLINK_MSG_SCALED_PRESSURE, 16},
		 {Msp.Cmds.MAVLINK_MSG_ATTITUDE, 28},
		 {Msp.Cmds.MAVLINK_MSG_RC_CHANNELS_RAW, 22},
		 {Msp.Cmds.MAVLINK_MSG_RC_CHANNELS, 42},
		 {Msp.Cmds.MAVLINK_MSG_GPS_GLOBAL_ORIGIN, 16},
		 {Msp.Cmds.MAVLINK_MSG_VFR_HUD, 20},
		 {Msp.Cmds.MAVLINK_MSG_ID_RADIO_STATUS, 9},
		 {Msp.Cmds.MAVLINK_MSG_ID_RADIO, 9},
		 {Msp.Cmds.MAVLINK_MSG_BATTERY_STATUS, 54},
		 {Msp.Cmds.MAVLINK_MSG_STATUSTEXT, 54},
		 {Msp.Cmds.MAVLINK_MSG_ID_TRAFFIC_REPORT, 38},
		 {Msp.Cmds.MAVLINK_MSG_ID_AUTOPILOT_VERSION, 78},
	 };

	 uint32 find_size(uint cmd) {
		 cmd += Msp.MAV_BASE;
		 for(int i = 0; i < sizes.length; i++) {
			 if(cmd == sizes[i].msgid) {
				 return sizes[i].size;
			 }
		 }
		 return 0;
	 }
 }

 private class MavCRC : Object {
	 private struct MavCRCList {
		 uint32 msgid;
		 uint8 seed;
	 }
	 /*
	   generated from mavlink library, standard.h, via mavcrc.go
	 */
	 private const MavCRCList mavcrcs[] = {
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
		 { 166, 21}, { 202, 7}, { 203, 85},
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
	 };

	 public static uint8 lookup(uint32 id) {
		 uint8 res = 0;
		 foreach (var v in mavcrcs) {
			 if (v.msgid == id) {
				 res = v.seed;
				 break;
			 }
		 }
		 return res;
	 }

	 public static uint16 crc(uint16 acc, uint8 val) {
		 uint8 tmp;
		 tmp = val ^ (uint8)(acc&0xff);
		 tmp ^= (tmp<<4);
		 acc = (acc>>8) ^ (tmp<<8) ^ (tmp<<3) ^ (tmp>>4);
		 return acc;
	 }
 }

 namespace CRSF {
	 const uint8 BROADCAST_ADDRESS = 0x00;
	 const uint8 RADIO_ADDRESS = 0xea;

	 const uint8 TELEMETRY_RX_PACKET_SIZE = 128;
	 static uint8 crsf_buffer[128];
	 static uint8 crsf_index;
	 static uint8 detect_idx=0;

	 bool check_crc(uint8 []buffer) {
		 uint8 len = buffer[1];
		 uint8 crc = 0;
		 for(var k = 2; k <= len; k++) {
			 crc = CRC8.dvb_s2(crc, crsf_buffer[k]);
		 }
		 return (crc == buffer[len+1]);
	 }

	 int crsf_decode(uint8 data) {
		 if (crsf_index == 0 && data != RADIO_ADDRESS) {
			 return -1;
		 }

		 if (crsf_index == 1 && (data < 2 || data > TELEMETRY_RX_PACKET_SIZE-2)) {
			 crsf_index = 0;
			 return -1;
		 }

		 if (crsf_index < TELEMETRY_RX_PACKET_SIZE) {
			 crsf_buffer[crsf_index] = data;
			 crsf_index++;
		 } else {
			 crsf_index = 0;
		 }

		 if (crsf_index > 4) {
			 uint8 len = crsf_buffer[1];
			 if (len + 2 == crsf_index) {
				 crsf_index = 0;
				 return len;
			 }
		 }
		 return 0;
	 }
 }

 namespace MPM {
	 enum State {
		 L_TYPE,
		 L_LEN,
		 L_DATA,
		 L_SKIP,
		 L_M,
		 L_P
	 }

	 public enum Mtype {
		 MPM_NONE = 0,
		 MPM_STATUS = 1,
		 MPM_FRSKY = 2,
		 MPM_FRHUB = 3,
		 MPM_DSM_T = 4,
		 MPM_DSM_B = 5,
		 MPM_FLYSKYAA = 6,
		 MPM_UNUSED1 = 7,
		 MPM_ISYNC = 8,
		 MPM_UNUSED2 = 9,
		 MPM_HITEC = 0xa,
		 MPM_SPEKSCAN = 0xb,
		 MPM_FLYSKYAC = 0xc,
		 MPM_CHANFWD = 0xd,
		 MPM_HOTT = 0xe,
		 MPM_MLINK = 0xf,
		 MPM_CONFIG = 0x10,
		 MPM_PLIST = 0x11,
		 MPM_MAXTYPE = 0x12
	 }

	 static uint8 mpm_buf[64];
	 static uint8 skip = 0;
	 static Mtype type = Mtype.MPM_NONE;
	 static State state = State.L_TYPE;
	 //                      0    1   2  3   4   5   6  7  8  9  a  b   c  d   e  f  10 11
	 const uint8 []tlens = {0, 0x18, 9, 9, 16, 16, 29, 0, 4, 0, 8, 6, 29, 0, 14, 10, 22, 0};


	 public uint8[] get_buffer() {
		 return mpm_buf;
	 }

	 public Mtype decode(uint8 c) {
		 Mtype res = Mtype.MPM_NONE;
		 switch (state) {
		 case State.L_M:
			 if (c == 'M') {
				 state = State.L_P;
			 }
			 break;
		 case State.L_P:
			 if (c == 'P') {
				 state = State.L_TYPE;
			 } else {
				 state = State.L_M;
			 }
			 break;
		 case State.L_TYPE:
			 if (c == 'M') {
				 state = State.L_P;
			 } else if (c > 0 && c < Mtype.MPM_MAXTYPE &&
				 c != Mtype.MPM_UNUSED1 && c != Mtype.MPM_UNUSED2 )  {
				 type = (Mtype)c;
				 state = State.L_LEN;
			 } else {
				 state = State.L_TYPE;
			 }
			 break;
		 case State.L_LEN:
			 var tl  = tlens[type];
			 if (tl != 0 && c == tl) {
				 if (type == Mtype.MPM_FRSKY || type == Mtype.MPM_FLYSKYAA) {
					 state = State.L_DATA;
				 } else {
					 state = State.L_SKIP;
				 }
				 skip = tl;
			 } else {
				 state = State.L_TYPE;
			 }
			 break;
		 case State.L_DATA:
			 mpm_buf[tlens[type] - skip] = c;
			 skip--;
			 if (skip == 0) {
				 state = State.L_TYPE;
				 res = type;
			 }
			 break;
		 case State.L_SKIP:
			 skip--;
			 if (skip == 0) {
				 state = State.L_TYPE;
			 }
			 break;
		 }
		 return res;
	 }
 }

 namespace CRC8 {
	 const uint8 crc8_dvb_s2_tab[] = {
		 0x00, 0xd5, 0x7f, 0xaa, 0xfe, 0x2b, 0x81, 0x54,
		 0x29, 0xfc, 0x56, 0x83, 0xd7, 0x02, 0xa8, 0x7d,
		 0x52, 0x87, 0x2d, 0xf8, 0xac, 0x79, 0xd3, 0x06,
		 0x7b, 0xae, 0x04, 0xd1, 0x85, 0x50, 0xfa, 0x2f,
		 0xa4, 0x71, 0xdb, 0x0e, 0x5a, 0x8f, 0x25, 0xf0,
		 0x8d, 0x58, 0xf2, 0x27, 0x73, 0xa6, 0x0c, 0xd9,
		 0xf6, 0x23, 0x89, 0x5c, 0x08, 0xdd, 0x77, 0xa2,
		 0xdf, 0x0a, 0xa0, 0x75, 0x21, 0xf4, 0x5e, 0x8b,
		 0x9d, 0x48, 0xe2, 0x37, 0x63, 0xb6, 0x1c, 0xc9,
		 0xb4, 0x61, 0xcb, 0x1e, 0x4a, 0x9f, 0x35, 0xe0,
		 0xcf, 0x1a, 0xb0, 0x65, 0x31, 0xe4, 0x4e, 0x9b,
		 0xe6, 0x33, 0x99, 0x4c, 0x18, 0xcd, 0x67, 0xb2,
		 0x39, 0xec, 0x46, 0x93, 0xc7, 0x12, 0xb8, 0x6d,
		 0x10, 0xc5, 0x6f, 0xba, 0xee, 0x3b, 0x91, 0x44,
		 0x6b, 0xbe, 0x14, 0xc1, 0x95, 0x40, 0xea, 0x3f,
		 0x42, 0x97, 0x3d, 0xe8, 0xbc, 0x69, 0xc3, 0x16,
		 0xef, 0x3a, 0x90, 0x45, 0x11, 0xc4, 0x6e, 0xbb,
		 0xc6, 0x13, 0xb9, 0x6c, 0x38, 0xed, 0x47, 0x92,
		 0xbd, 0x68, 0xc2, 0x17, 0x43, 0x96, 0x3c, 0xe9,
		 0x94, 0x41, 0xeb, 0x3e, 0x6a, 0xbf, 0x15, 0xc0,
		 0x4b, 0x9e, 0x34, 0xe1, 0xb5, 0x60, 0xca, 0x1f,
		 0x62, 0xb7, 0x1d, 0xc8, 0x9c, 0x49, 0xe3, 0x36,
		 0x19, 0xcc, 0x66, 0xb3, 0xe7, 0x32, 0x98, 0x4d,
		 0x30, 0xe5, 0x4f, 0x9a, 0xce, 0x1b, 0xb1, 0x64,
		 0x72, 0xa7, 0x0d, 0xd8, 0x8c, 0x59, 0xf3, 0x26,
		 0x5b, 0x8e, 0x24, 0xf1, 0xa5, 0x70, 0xda, 0x0f,
		 0x20, 0xf5, 0x5f, 0x8a, 0xde, 0x0b, 0xa1, 0x74,
		 0x09, 0xdc, 0x76, 0xa3, 0xf7, 0x22, 0x88, 0x5d,
		 0xd6, 0x03, 0xa9, 0x7c, 0x28, 0xfd, 0x57, 0x82,
		 0xff, 0x2a, 0x80, 0x55, 0x01, 0xd4, 0x7e, 0xab,
		 0x84, 0x51, 0xfb, 0x2e, 0x7a, 0xaf, 0x05, 0xd0,
		 0xad, 0x78, 0xd2, 0x07, 0x53, 0x86, 0x2c, 0xf9};

	 public uint8 dvb_s2(uint8 crc, uint8 a) {
		 crc ^= a;
		 return crc8_dvb_s2_tab[crc];
	 }
 }

 public class MWSerial : Object {
	 public enum PMask {
		 AUTO = 0xff,
		 INAV = 1,
		 SPORT = 2,
		 CRSF = 4,
		 MPM = 8,
	 }
	 private string devname;
	 private int fd=-1;
	 private int wrfd=-1;
	 private Socket socket;
	 private SocketAddress sockaddr;
	 public  States state {private set; get;}
	 private uint8 xflags;
	 private uint8 checksum;
	 private uint8 checksum2;
	 private uint16 csize;
	 private uint16 needed;
	 private uint16 xcmd;
	 private Msp.Cmds cmd;
	 private int irxbufp;
	 private uint16 rxbuf_alloc;
	 private uint16 txbuf_alloc = 256;
	 private uint8 []rxbuf;
	 private uint8 []txbuf;
	 public bool available {private set; get;}
	 public bool is_main ;
	 public bool force4 = false;
	 private char readdirn {set; get; default= '>';}
	 private char writedirn {set; get; default= '<';}
	 private bool errstate;
	 private int commerr;
	 private bool rawlog;
	 private FileStream  raws;
	 //	 private int raws;
	 private Timer timer;
	 private bool print_raw=false;
	 public uint baudrate  {private set; get;}
	 private int sp = 0;
	 private int64 stime;
	 private int64 ltime;
	 private SerialStats stats;
	 private int commode;
	 private uint16 mavsum;
	 private uint16 rxmavsum;
	 private bool encap = false;
	 public bool use_v2 = false;
	 public ProtoMode pmode  {set; get; default=ProtoMode.NORMAL;}
	 private bool fwd = false;
	 private bool ro = false;
	 private uint8 mavseqno = 0;
	 private uint8[] devbuf;
	 private uint16 mavsig = 0;
	 private bool relaxed;
	 private PMask pmask;
	 private bool mpm_auto = false;
	 private int lasterr = 0;
	 private string errstr =null;
	 private DevMask dtype;
	 public static bool debug;
	 public TrackData td;
	 public AsyncQueue<INAVEvent?> msgq;
	 public uint8 mavvid;
	 public uint8 mavsysid;
#if LINUX
	 private BleSerial gs;
 #endif
	 private uint tag;
	 private ulong slcid;
	 private IOChannel io_chan;
#if WINDOWS
	 public DataInputStream? dis;
	 public DataOutputStream? dos;
	 public Cancellable can;
#endif
	 private const int WEAKSIZE = 16;

	 public enum MemAlloc {
		 RX=1024,
		 TX=256,
		 DEV=2048
	 }

	 [Flags]
	 public enum ComMode {
		 TTY,
		 BT,
		 BLE,
		 WEAK,
		 WEAKBLE,
		 UDP,
		 TCP,
		 UDPSERVER,
		 IPCONN
	 }

	 public enum Mode {
		 NORMAL=0,
		 SIM = 1
	 }

	 public enum ProtoMode {
		 NORMAL,
		 CLI,
		 FRSKY
	 }

	 public enum States {
		 S_END=0,
		 S_HEADER,
		 S_HEADER1,
		 S_HEADER2,
		 S_SIZE,
		 S_CMD,
		 S_DATA,
		 S_CHECKSUM,
		 S_ERROR,
		 S_JUMBO1,
		 S_JUMBO2,
		 S_T_HEADER2=100,
		 S_X_HEADER2=200,
		 S_X_FLAGS,
		 S_X_ID1,
		 S_X_ID2,
		 S_X_LEN1,
		 S_X_LEN2,
		 S_X_DATA,
		 S_X_CHECKSUM,
		 S_M_STX = 300,
		 S_M_SIZE,
		 S_M_SEQ,
		 S_M_ID1,
		 S_M_ID2,
		 S_M_MSGID,
		 S_M_DATA,
		 S_M_CRC1,
		 S_M_CRC2,
		 S_M2_STX = 400,
		 S_M2_SIZE,
		 S_M2_FLG1,
		 S_M2_FLG2,
		 S_M2_SEQ,
		 S_M2_ID1,
		 S_M2_ID2,
		 S_M2_MSGID0,
		 S_M2_MSGID1,
		 S_M2_MSGID2,
		 S_M2_DATA,
		 S_M2_CRC1,
		 S_M2_CRC2,
		 S_M2_SIG,
		 S_CRSF_OK = 500,
		 S_SPORT_OK,
		 S_MPM_P = 600,
	 }

	 const uint8 MAVID2= 190;

	 public struct INAVEvent {
		 public Msp.Cmds cmd;
		 public uint len;
		 public uint8 flags;
		 public bool err;
		 public uint8[]raw;
	 }

	 public signal void serial_lost ();
	 public signal void serial_event();
	 public signal void crsf_event();
	 public signal void flysky_event();
	 public signal void cli_event();
	 public signal void sport_event();

	 public static PMask name_to_pmask(string name) {
		 switch(name.down()) {
		 case "inav":
		 case "1":
			 return PMask.INAV;
		 case "sport":
		 case "s.port":
		 case "2":
			 return PMask.SPORT;
		 case "crsf":
		 case "4":
			 return PMask.CRSF;
		 case "mpm":
		 case "8":
			 return PMask.MPM;
		 default:
			 return PMask.AUTO;
		 }
	 }

	 public static string pmask_to_name(PMask pmask) {
		 switch(pmask) {
		 case PMask.INAV:
			 return "INAV";
		 case PMask.CRSF:
			 return "CRSF";
		 case PMask.SPORT:
			 return "Sport";
		 case PMask.MPM:
			 return "MPM";
		 case PMask.AUTO:
			 return "Auto";
		 default:
			 return "????";
		 }
	 }

	 public static uint pmask_to_index(PMask pmask) {
		 switch(pmask) {
		 case PMask.AUTO:
			 return 0;
		 case PMask.INAV:
			 return 1;
		 case PMask.SPORT:
			 return 2;
		 case PMask.CRSF:
			 return 3;
		 case PMask.MPM:
			 return 4;
		 default:
			 return 0;
		 }
	 }

	 public void set_dmask(DevMask dm) {
		 dtype = dm;
	 }
	 public DevMask get_dmask() {
		 return dtype;
	 }

	 public int randomUDP(int[] res) {
		 int result = -1;
		 commode = 0;
		 setup_ip(null,0);
		 if (fd > -1) {
			 try {
				 var xsa = socket.get_local_address();
				 var outp = ((InetSocketAddress)xsa).get_port();
				 res[0] = fd;
				 res[1] = (int)outp;
				 result = 0;
				 available = true;
				 devname = "udp #%d".printf(outp);
				 MWPLog.message("random UDP addr %s\n", xsa.to_string());
				 setup_reader();
			 } catch (Error e) {
				 MWPLog.message("randomIP: %s\n", e.message);
			 }
		 }
		 return result;
	 }

	 public string get_devname() {
		 return devname;
	 }

	 public bool get_ro() {
		 return ro;
	 }

	 public void set_ro(bool _ro) {
		 ro = _ro;
	 }

	 public MWSerial.forwarder() {
		 fwd = true;
		 available = false;
		 set_txbuf(MemAlloc.TX);
		 pmask = PMask.AUTO;
		 mavsysid = 'j';
		 mavvid = 0;
	 }

	 public MWSerial() {
		 mavvid = 0;
		 fwd =  available = false;
		 rxbuf_alloc = MemAlloc.RX;
		 rxbuf = new uint8[rxbuf_alloc];
		 txbuf = new uint8[txbuf_alloc];
		 devbuf = new uint8[MemAlloc.DEV];
		 pmask = PMask.AUTO ;
	 }

	 public bool is_weak() {
		 return ((commode & ComMode.WEAK) == ComMode.WEAK);
	 }

	 public bool is_weakble() {
		 return ((commode & ComMode.WEAKBLE) == ComMode.WEAKBLE);
	 }

	 public void set_weak() {
		 commode |= ComMode.WEAK;
	 }

	 public int get_commode() {
		 return commode;
	 }

	 public void set_pmask(PMask _pm) {
		 pmask = _pm;
	 }

	 public void set_auto_mpm(bool _a) {
		 mpm_auto = _a;
	 }

	 public int get_fd() {
		 return fd;
	 }

	 public void set_txbuf(uint16 sz) {
		 txbuf = new uint8[sz];
		 txbuf_alloc = sz;
	 }

	 public uint16 get_txbuf() {
		 return txbuf_alloc;
	 }

	 public uint16 get_rxbuf() {
		 return rxbuf_alloc;
	 }

	 public void clear_counters() {
		 ltime = stime = 0;
		 stats =  {0};
	 }

	 public void setup_reader() {
		 clear_counters();
		 state = States.S_HEADER;
		 msgq = new AsyncQueue<INAVEvent?>();
		 td = {};
#if WINDOWS
		 if((commode & ComMode.TTY) != 0) {
			 can = new Cancellable();
			 if (!fwd) {
				 dis = new DataInputStream (new Win32InputStream((void *)((intptr)fd), false));
			 }
			 dos = new DataOutputStream (new Win32OutputStream((void *)((intptr)wrfd), false));
		 }
#endif
		 if(!fwd) {
			 slcid = serial_lost.connect(() => {
					 clearup();
				 });
			 device_io();
		 }
	 }

#if WINDOWS
	 public async bool sfetch() {
		 for(;;) {
			 try {
				 var len = yield dis.read_async(devbuf, Priority.DEFAULT, can);
				 if (len >  0) {
					process_input(len);
				 } else {
					 var err = MwpSerial.get_error_number();
					 if (err != 0 && err != ERROR_TIMEOUT) {
						 return false;
					 }
				 }
			 } catch (Error e) {
				 MWPLog.message("Read async: %s\n", e.message);
				 if (!can.is_cancelled()) {
					 serial_lost();
				 }
				 return false;
			 }
		 }
	}
#endif

	 private void ufetch() {
#if WINDOWS
		 io_chan = new IOChannel.win32_socket(socket.fd);
#else
		 io_chan = new IOChannel.unix_new(fd);
#endif
		 try {
			 if(io_chan.set_encoding(null) != IOStatus.NORMAL)
				 error("Failed to set encoding");
			 io_chan.set_buffered(false);
			 tag = io_chan.add_watch(IOCondition.IN|
									 IOCondition.HUP|
									 IOCondition.ERR|
									 IOCondition.NVAL, (chan, cond) => {
										 var acond = cond & ~IOCondition.IN;
										 if (acond != 0) {
											 lasterr = MwpSerial.get_error_number();
											 var estr = format_last_err();
											 var cstr = format_condition(cond);
											 MWPLog.message("Serial Condition: %s %s\n", estr, cstr);
											 serial_lost();
											 return false;
										 }
										 try {
											 size_t sz = 0;
											 if(ComMode.UDP in commode) {
												 sz = socket.receive_from(out sockaddr, devbuf);
											 } else if (ComMode.TTY in commode) {
												 sz = MwpSerial.read(fd, devbuf, MemAlloc.DEV);
											 } else {
												 var iostat = io_chan.read_chars((char[])devbuf, out sz);
												 if(iostat != IOStatus.NORMAL) {
													 MWPLog.message("Read IOStatus %x %s\r\n", iostat, iostat.to_string());
													 serial_lost();
													 return false;
												 }
											 }
											 if (sz <= 0) {
												 MWPLog.message("Serial read: %d\n", sz);
												 lasterr = MwpSerial.get_error_number();
												 var estr = format_last_err();
												 var cstr = format_condition(cond);
												 MWPLog.message("Serial Read Condition: %s %s\n", estr, cstr);
												 serial_lost();
												 return false;
											 }
											 process_input(sz);
											 return true;
										 } catch (Error e) {
											 MWPLog.message(":DBG: IORead %s\n", e.message);
											 serial_lost();
											 return false;
										 }
									 });
		 } catch (Error e) {
			 MWPLog.message(":DBG: UDP setup %s\n", e.message);
		 }
	 }

	 public void device_io() {
#if !WINDOWS
		 ufetch();
#else
		 if((commode & ComMode.TTY) != 0) {
			 sfetch.begin((obj, res) => {
					 var ok = sfetch.end(res);
					 if(!ok) {
						 try {
							 dos.close();
							 dis.close();
							 serial_lost();
						 } catch (Error e) {
							 MWPLog.message("SFetch close: %s\r\n", e.message);
						 }
					 }
				 });
		 } else {
			 ufetch();
		 }
#endif
	 }

	 private void setup_ip(string? host, uint16 port, string? rhost=null, uint16 rport = 0) {
		 fd = -1;
		 baudrate = 0;

		 if(host == null || host.length == 0) {
			 SocketFamily[] fams = {};
			 if(!force4) {
				 fams += SocketFamily.IPV6;
			 }

			 foreach(var ifam in fams) {
				 try {
					 var sa = sockaddr= new InetSocketAddress (new InetAddress.any(ifam), (uint16)port);
					 socket = new Socket (ifam, SocketType.DATAGRAM, SocketProtocol.UDP);
					 if (socket != null) {
 #if WINDOWS
						 if (ifam == SocketFamily.IPV6) {
							 int err = WinFix.set_v6_dual_stack(socket.fd);
							 if (err != 0) {
								 var _lerr = MwpSerial.get_error_number();
								 uint8 [] sbuf = new uint8[1024];
								 var s = MwpSerial.error_text(_lerr, sbuf, 1024);
								 MWPLog.message("::DBG:: Windwos IPV6 trainwreck %s\n", s);
							 } else {
								 MWPLog.message("::DBG:: Fixup Windwos IPV6 %d\n", err);
							 }
						 }
 #endif
						 socket.bind (sa, true);
						 fd = socket.fd;
						 if(debug) {
							 MWPLog.message(":DBG: UDP bound: %s fd=%d\n", socket.get_local_address().to_string(), fd);
						 }
						 commode |= ComMode.UDP|ComMode.UDPSERVER;
						 break;
					 }
				 } catch (Error e) {
					 MWPLog.message ("Bind %s\n", e.message);
					 lasterr = MwpSerial.get_error_number();
				 }
			 }
			 if(rhost != null && rport != 0) {
				 try {
					 var resolver = Resolver.get_default ();
					 var addresses = resolver.lookup_by_name (rhost, null);
					 var addr0 = addresses.nth_data (0);
					 sockaddr = new InetSocketAddress(addr0,rport);
				 } catch (Error e) {
					 MWPLog.message ("RBind %s\n", e.message);
					 lasterr = MwpSerial.get_error_number();
				 }
			 }
		 } else {
			 SocketProtocol sproto;
			 SocketType stype;
			 List<InetAddress> addresses = null;

			 var resolver = Resolver.get_default ();
			 try {
				 addresses = resolver.lookup_by_name (host, null);
			 } catch (Error e) {
				 MWPLog.message ("resolver: %s\n", e.message);
				 errstr = e.message;
				 lasterr = MwpSerial.get_error_number();
			 }

			 try {
				 if (addresses != null) {
					 foreach (var address in addresses) {
						 sockaddr = new InetSocketAddress (address, port);
						 var fam = sockaddr.get_family();
						 if(debug) {
							 MWPLog.message("sockaddr try %s (%s)\n", sockaddr.to_string(), fam.to_string());
						 }
						 if(force4 && fam != SocketFamily.IPV4)
							 continue;

						 if((commode & ComMode.TCP) == ComMode.TCP) {
							 stype = SocketType.STREAM;
							 sproto = SocketProtocol.TCP;
						 } else {
							 stype = SocketType.DATAGRAM;
							 sproto = SocketProtocol.UDP;
							 commode |= ComMode.UDP;
						 }
						 socket = new Socket (fam, stype, sproto);
						 fd = socket.fd;
						 if(fd != -1) {
							 wrfd = fd;
							 if (sproto != SocketProtocol.UDP) {
								 socket.connect(sockaddr);
							 }
							 socket.set_blocking(false);
						 }
						 MWPLog.message("IP Client %s\n", fam.to_string());
						 break;
					 }
				 }
			 } catch(Error e) {
				 MWPLog.message("client socket: %s %d: %s\n", host, port, e.message);
				 lasterr = MwpSerial.get_error_number();
				 fd = -1;
			 }
		 }
		 if (fd != -1) {
			 commode |= ComMode.IPCONN;
			 available = true;
		}
	 }

	 private void set_noblock(int _fd) {
 #if UNIX
		 try {
			 Unix.set_fd_nonblocking(_fd, true);
		 } catch {};
 #endif
	 }

	 private string format_last_err() {
		 uint8 [] sbuf = new uint8[1024];
		 var s = MwpSerial.error_text(lasterr, sbuf, 1024);
		 return "%s %s (%d)".printf(devname, s, lasterr);
	 }

	 public void get_error_message(out string estr) {
		 estr = "";
		 if(errstr == null) {
			 estr = format_last_err();
		 } else {
			 estr = errstr;
			 errstr = null;
		 }
		 MWPLog.message("%s\n", estr);
	 }

	 public async bool open_async(string device, uint rate) {
		 var thr = new Thread<bool> (device, () => {
				 var res = open_w(device, rate);
				 Idle.add (open_async.callback);
				 return res;
			 });
		 yield;
		 return thr.join();
	 }

	 public bool open(string device, uint rate, out string estr) {
		 estr="";
		 if(open_w(device, rate)) {
			 if(fwd == false) {
				 setup_reader();
			 } else {
				 set_noblock(fd);
			 }
		 } else  {
			 get_error_message(out estr);
		 }
		 return available;
	 }

	 private string resolve_mwp_serial_host() {
		 var host = Environment.get_variable("MWP_SERIAL_HOST");
		 if(host == null) {
			 string []  routes = {
				 "sh -c \"ip route show 0.0.0.0/0 | cut -d ' ' -f3\"",
				 "sh -c \"route -n | grep UG | awk '{print $2}'\"",
				 "sh -c \"route -n show  0.0.0.0 | grep gateway | awk '{print $2}'\""
			 };
			 int rstatus;
			 string rerr;

			 foreach (var cmd in routes) {
				 try {
					 Process.spawn_command_line_sync (cmd, out host, out rerr, out rstatus);
					 if (rstatus == 0 && host != null && host.length > 0) {
						 host = host.chomp();
						 break;
					 }
				 } catch (Error e) {print("%s\n", e.message);};
			 }
		 }
		 return host;
	 }

	 public bool open_w (string _device, uint rate) {
		 string device;
		 wrfd = -1;
		 int n;
		 if((n = _device.index_of_char(' ')) == -1) {
			 device = _device;
		 } else {
			 device = _device.substring(0,n);
		 }

		 devname = device;
		 print_raw = (Environment.get_variable("MWP_PRINT_RAW") != null);
		 commode = 0;
		 var u = UriParser.dev_parse(device);
		 //MWPLog.message("UPARSE %s", u.to_string());
		 var dd = DevManager.get_dd_for_name(u.path);
		 if(dd != null && DevMask.BT in dd.type) {
			 //MWPLog.message("DD %s %s\n", dd.name, dd.alias);
#if LINUX
			 bool bleok = false;
			 if ((dd.type & DevMask.BTLE) == DevMask.BTLE) {
				 //MWPLog.message("BTLE device\n");
				 gs = new BleSerial(dd.gid);
				 commode = ComMode.BLE|ComMode.BT;
				 if(DevManager.btmgr.set_device_connected(dd.id, true)) {
					 var tc = 0;
					 while (!DevManager.btmgr.get_device(dd.id).is_connected) {
						 Thread.usleep(5000);
						 tc++;
						 if(tc > 200) {
							 break;
						 }
					 }
					 tc = 0;
					 while(!gs.find_service(DevManager.btmgr, dd.id)) {
						 Thread.usleep(5000);
						 tc++;
						 if(tc > 100) {
							 break;
						 }
					 }
					 var cset = gs.get_chipset();
					 Thread.usleep(10000); // 10ms
					 var mtu = gs.get_bridge_fds(DevManager.btmgr, dd.id, out fd, out wrfd);
					 var xstr = "";
					 if (mtu < 200) {
						 xstr = " (unlikely to end well)";
					 }
					 MWPLog.message("BLE chipset %s, mtu %d%s\n", cset, mtu, xstr);
					 bleok = (mtu > 0);
					 if (mtu < 64) {
						 commode |= (ComMode.WEAK|ComMode.WEAKBLE);
					 }
				 }
				 if(!bleok || fd == -1){
					 fd = -1;
					 available = false;
					 lasterr = Posix.ETIMEDOUT;
				 } else {
					 set_noblock(fd);
					 if (fd != wrfd) {
						 set_noblock(wrfd);
					 }
					 available = true;
				 }
			 } else
#endif
			 {
				 //				 MWPLog.message("BT Legacy %s\n", dd.name);
				 fd = BTSocket.connect(dd.name, &lasterr);
				 if (fd != -1) {
					 wrfd = fd;
					 commode = ComMode.BT;
					 lasterr = 0;
					 set_noblock(fd);
					 available = true;
				 } else {
					 lasterr=MwpSerial.get_error_number();
				 }
			 }
			 if(!available) {
				 clearup();
			 }
		 } else if (u.scheme == "tcp" || u.scheme == "udp") {
			 string host = null;
			 uint16 port = 0;
			 string remhost = null;
			 uint16 remport = 0;

			 if(u.scheme == "tcp") {
				 commode = ComMode.TCP;
			 }
			 if(u.port != -1) {
				 port = (uint16)u.port;
			 }

			 if (u.host == null) {
				 host = "";
			 } else {
				 host = u.host;
			 }

			 /* sort out new and legacy rem stuff */
			 if (u.path != null) {
				 var parts = u.path.split(":");
				 if (parts.length == 2) {
					 remhost = parts[0][1:parts[0].length];
					 remport = (uint16)int.parse(parts[1]);
				 }
			 }
			 if (u.qhash != null) {
				 var v = u.qhash.get("bind");
				 if (v != null) {
					 remhost = u.host;
					 remport = (uint16)u.port;
					 port = (uint16)int.parse(v);
					 host = "";
				 }
			 }
			 if(host != null) {
				 if (u.host == "__MWP_SERIAL_HOST") {
					 host = resolve_mwp_serial_host();
				 }
				 setup_ip(host, port, remhost, remport);
			 }
		 } else {
			 commode = ComMode.TTY;
			 var parts = u.path.split ("@");
			 if(parts.length == 2) {
				 device  = parts[0];
				 rate = int.parse(parts[1]);
			 } else {
				 device  = u.path;
				 if (u.qhash != null) {
					 var v = u.qhash.get("baud");
					 if (v != null) {
						 rate = int.parse(v);
					 }
				 }
			 }
			 fd = MwpSerial.open(device, (int)rate);
			 if(fd < 0) {
				 lasterr = MwpSerial.get_error_number();
			 } else {
				 clear_counters();
				 available = true;
				 wrfd = fd;
				 set_noblock(fd);
			 }
		 }
		 return available;
	 }

	 ~MWSerial() {
		 if(fd != -1) {
			 close();
		 }
	 }

	 public void close() {
		 if(fwd) {
			 clearup();
		 } else if(available) {
#if WINDOWS
			 if((commode & ComMode.TTY) != 0) {
				 if (can != null) {
					 can.cancel();
				 }
			 }
#endif
			 if (io_chan != null) {
				 try {
					 io_chan.shutdown(false);
#if WINDOWS
					 // Fuck you windows, rudely ,gratuitouly incompatible, fuck you
					 serial_lost();
#endif
				 } catch (Error e) {
					 MWPLog.message(":DBG: iochan shutdown %s\n", e.message);
				 }
			 }
		 }
    }

	 private void clearup() {
		 if (slcid != 0) {
			 this.disconnect(slcid);
			 slcid = 0;
		 }

		 if(fd != -1) {
			 try {
				 if (ComMode.TTY in commode) {
					 MwpSerial.close(fd);
				 } else if (ComMode.TCP in commode) {
					 socket.shutdown(true, true);
				 } else if (ComMode.BT in commode && ((commode & ComMode.BLE) == 0)) {
					 Posix.close(fd);
				 }
				 if (ComMode.IPCONN in commode) {
					 socket.close();
				 }
#if LINUX
				 if((commode & ComMode.BLE) == ComMode.BLE) {
					 Posix.close(fd);
					 if (wrfd != fd) {
						 Posix.close(wrfd);
					 }
				 }
#endif
			 } catch (Error e) {
				 MWPLog.message("Closedown: %s\r\n", e.message);
			 }
		 }
#if LINUX
		 if((commode & ComMode.BLE) == ComMode.BLE) {
			 var dd = DevManager.get_dd_for_name(devname);
			 if (dd != null) {
				 DevManager.btmgr.set_device_connected(dd.id, false);
			 }
		 }
#endif
		 fd = wrfd = -1;
		 commode = 0;
		 sockaddr=null;
		 socket = null;
		 if (tag > 0) {
			 Source.remove(tag);
			 tag = 0;
		 }
		 td.r = null;
		 td = {};
		 available = false;
		 io_chan = null;
#if WINDOWS
		 dis = null;
		 dos = null;
#endif
	 }

	 public async bool close_async() {
		 var thr = new Thread<bool> ("aclose",  () => {
				 close();
				 Idle.add (close_async.callback);
				 return true;
			 });
		 yield;
		 return thr.join();
	 }

	 public SerialStats dump_stats() {
		 if(stime == 0)
			 stime =  GLib.get_monotonic_time();
		 if(ltime == 0 || ltime == stime)
			 ltime =  GLib.get_monotonic_time();
		 stats.elapsed = (ltime - stime)/1000000.0;
		 if (stats.elapsed > 0) {
			 stats.txrate = stats.txbytes / stats.elapsed;
			 stats.rxrate = stats.rxbytes / stats.elapsed;
		 }
		 return stats;
	 }

	 private void error_counter(string? why=null) {
		 commerr++;
		 MWPLog.message("Comms error %s %d\n", (why!=null) ? why : "", commerr);
		 MwpSerial.flush(fd);
	 }

	 private void check_rxbuf_size() {
		 if (csize > rxbuf_alloc) {
			 while (csize > rxbuf_alloc)
				 rxbuf_alloc += MemAlloc.RX;
			 rxbuf = new uint8[rxbuf_alloc];
		 }
	 }

	 private void check_txbuf_size(size_t sz) {
		 if (sz > txbuf_alloc) {
			 while (sz > txbuf_alloc)
				 txbuf_alloc += MemAlloc.TX;
			 txbuf = new uint8[txbuf_alloc];
		 }
	 }

	 private bool fr_publish(uint8 []buf) {
		 bool res = SportDev.fr_checksum(buf);
		 if(res) {
			 var msg = INAVEvent(){cmd=0, len=0, flags=0, err=false, raw=buf};
			 msgq.push(msg);
			 sport_event();
			 stats.msgs++;
		 }
		 return res;
	 }

	 private bool process_input(size_t res) {
		 if(pmode == ProtoMode.CLI) {
			 csize = (uint16)res;
			 var msg = INAVEvent(){cmd=0, len=csize, flags=0, err=false, raw=devbuf};
			 msgq.push(msg);
			 Idle.add(() => {cli_event();return false;});
		 } else {
			 if(stime == 0) {
				 stime =  GLib.get_monotonic_time();
			 }
			 ltime =  GLib.get_monotonic_time();
			 stats.rxbytes += res;
			 if(print_raw == true) {
				 dump_raw_data(devbuf, (int)res);
			 }
			 if(rawlog == true) {
				 log_raw('i', devbuf, (int)res);
			 }

			 for(var nc = 0; nc < res; nc++) {
				 if (pmask ==  PMask.MPM) {
					 var mpmres = MPM.decode(devbuf[nc]);
					 if(mpmres == MPM.Mtype.MPM_FRSKY) {
						 fr_publish(MPM.get_buffer());
					 } else if (mpmres == MPM.Mtype.MPM_FLYSKYAA) {
						 var fbuf = MPM.get_buffer();
						 var msg = INAVEvent(){cmd=0, len=0, flags=0, err=false, raw=fbuf};
						 msgq.push(msg);
						 flysky_event();
						 stats.msgs++;
					 }
				 } else {
					 switch(state) {
					 case States.S_ERROR:
					 case States.S_HEADER:
						 switch (devbuf[nc])  {
						 case '$':
							 if ((pmask & PMask.INAV) == PMask.INAV) {
								 sp = nc;
								 state=States.S_HEADER1;
								 errstate = false;
							 }
							 break;
						 case 0xfe:
							 if ((pmask & PMask.INAV) == PMask.INAV) {
								 sp = nc;
								 state=States.S_M_SIZE;
								 errstate = false;
								 mavvid = 1;
							 }
							 break;
						 case 0xfd:
							 if ((pmask & PMask.INAV) == PMask.INAV) {
								 sp = nc;
								 state=States.S_M2_SIZE;
								 errstate = false;
								 mavvid = 2;
							 }
							 break;
						 case CRSF.RADIO_ADDRESS:
							 if ((pmask & PMask.CRSF) == PMask.CRSF) {
								 CRSF.detect_idx = 0;
								 state = States.S_CRSF_OK;
								 if(debug) {
									 MWPLog.message("CRSF detect 0x%02x\n", devbuf[nc]);
								 }
								 CRSF.crsf_decode(devbuf[nc]);
							 }
							 break;
						 case SportDev.FrProto.P_START:
							 if ((pmask & PMask.SPORT) == PMask.SPORT) {
								 var sbx = SportDev.extract_messages(devbuf[nc]);
								 if (sbx == SportDev.FrStatus.PUBLISH) {
									 var sbuf = SportDev.get_buffer();
									 fr_publish(sbuf[1:10]);
									 state = States.S_SPORT_OK;
								 } else if(sbx != SportDev.FrStatus.OK) {
									 state = States.S_ERROR;
								 } else {
									 state = States.S_SPORT_OK;
								 }
							 }
							 break;
						 case 'M':
							 if(mpm_auto) {
								 if ((pmask & PMask.MPM) == PMask.MPM) {
									 state = States.S_MPM_P;
								 }
							 }
							 break;
						 default:
							 if (state == States.S_HEADER) {
								 MWPLog.message("Detect: expected header0 (0x%x %x)\n", devbuf[nc], pmask);
								 state=States.S_ERROR;
							 }
							 break;
						 }
						 break;

					 case States.S_MPM_P:
						 pmask = PMask.MPM;
						 break;

					 case States.S_SPORT_OK:
						 var sbx = SportDev.extract_messages(devbuf[nc]);
						 if (sbx == SportDev.FrStatus.PUBLISH) {
							 var sbuf = SportDev.get_buffer();
							 fr_publish(sbuf[1:10]);
						 } else if(sbx != SportDev.FrStatus.OK) {
							 error_counter("Sport/Proto");
							 state = States.S_ERROR;
						 }
						 break;

					 case States.S_CRSF_OK:
						 var crsf_len = CRSF.crsf_decode(devbuf[nc]);
						 if (crsf_len > 0) {
							 if (!CRSF.check_crc(CRSF.crsf_buffer)) {
								 if(debug) {
									 MWPLog.message("CRSF: CRC Fails\n");
								 }
								 crsf_len = -1;
							 } else {
								 var msg = INAVEvent(){cmd=0, len=crsf_len, flags=0, err=false, raw=CRSF.crsf_buffer};
								 msgq.push(msg);
								 crsf_event();
								 stats.msgs++;
							 }
						 }
						 if (crsf_len == -1) {
							 error_counter("CRSF/CRC");
							 state=States.S_ERROR;
						 }
						 break;

					 case States.S_HEADER1:
						 encap = false;
						 irxbufp=0;
						 if(devbuf[nc] == 'M') {
							 state=States.S_HEADER2;
						 } else if(devbuf[nc] == 'T') {
							 state=States.S_T_HEADER2;
						 } else if(devbuf[nc] == 'X') {
							 state=States.S_X_HEADER2;
						 } else {
							 error_counter("MSP/Proto");
							 if(debug) {
								 MWPLog.message("fail on header1 %x\n", devbuf[nc]);
							 }
							 state=States.S_ERROR;
						 }
						 break;

					 case States.S_T_HEADER2:
						 needed = 0;
						 switch(devbuf[nc]) {
						 case 'G':
							 needed = (uint16) MSize.LTM_GFRAME;
							 cmd = Msp.Cmds.TG_FRAME;
							 break;
						 case 'A':
							 needed = (uint16) MSize.LTM_AFRAME;
							 cmd = Msp.Cmds.TA_FRAME;
							 break;
						 case 'S':
							 needed = (uint16) MSize.LTM_SFRAME;
							 cmd = Msp.Cmds.TS_FRAME;
							 break;
						 case 'O':
							 needed = (uint16) MSize.LTM_OFRAME;
							 cmd = Msp.Cmds.TO_FRAME;
							 break;
						 case 'N':
							 needed = (uint16) MSize.LTM_NFRAME;
							 cmd = Msp.Cmds.TN_FRAME;
							 break;
						 case 'X':
							 needed = (uint16) MSize.LTM_XFRAME;
							 cmd = Msp.Cmds.TX_FRAME;
							 break;
							 // Lower case are 'private'
						 case 'q':
							 needed = 2;
							 cmd = Msp.Cmds.Tq_FRAME;
							 break;
						 case 'a':
							 needed = 2;
							 cmd = Msp.Cmds.Ta_FRAME;
							 break;
						 case 'r':
							 needed = 8;
							 cmd = Msp.Cmds.Tr_FRAME;
							 break;
						 case 'x':
							 needed = 1;
							 cmd = Msp.Cmds.Tx_FRAME;
							 break;
						 case 'w':
							 needed = 6;
							 cmd = Msp.Cmds.Tw_FRAME;
							 break;
						 default:
							 error_counter("LTM/Proto");
							 if(debug) {
								 MWPLog.message("fail on T_header2 %x\n", devbuf[nc]);
							 }
							 state=States.S_ERROR;
							 break;
						 }
						 if (needed > 0) {
							 csize = needed;
							 irxbufp = 0;
							 checksum = 0;
							 state = States.S_DATA;
						 }
						 break;

						 case States.S_HEADER2:
							 xflags = devbuf[nc];
							 if((devbuf[nc] == readdirn ||
								 devbuf[nc] == writedirn ||
								 devbuf[nc] == '!')) {
								 if (relaxed)
									 errstate = !(devbuf[nc] == readdirn ||
												  devbuf[nc] == writedirn);
								 else
									 errstate = (devbuf[nc] != readdirn); // == '!'
								 state = States.S_SIZE;
							 } else {
								 error_counter("MSP/Proto");
								 if(debug) {
									 MWPLog.message("fail on header2 %x\n", devbuf[nc]);
								 }
								 state=States.S_ERROR;
							 }
							 break;

					 case States.S_SIZE:
						 csize = devbuf[nc];
						 checksum = devbuf[nc];
						 state = States.S_CMD;
						 break;
					 case States.S_CMD:
						 cmd = (Msp.Cmds)devbuf[nc];
						 checksum ^= cmd;
						 if(cmd == Msp.Cmds.MSPV2) {
							 encap = true;
							 state = States.S_X_FLAGS;
						 } else if (csize == 255) {
							 state = States.S_JUMBO1;
						 } else {
							 if (csize == 0) {
								 state = States.S_CHECKSUM;
							 } else {
								 state = States.S_DATA;
								 irxbufp = 0;
								 needed = csize;
								 check_rxbuf_size();
							 }
						 }
						 break;

					 case States.S_JUMBO1:
						 checksum ^= devbuf[nc];
						 csize = devbuf[nc];
						 state = States.S_JUMBO2;
						 break;

					 case States.S_JUMBO2:
						 checksum ^= devbuf[nc];
						 csize |= (uint16)devbuf[nc] << 8;
						 needed = csize;
						 irxbufp = 0;
						 if (csize == 0)
							 state = States.S_CHECKSUM;
						 else {
							 state = States.S_DATA;
								 check_rxbuf_size();
						 }
						 break;

					 case States.S_DATA:
						 rxbuf[irxbufp++] = devbuf[nc];
						 checksum ^= devbuf[nc];
						 needed--;
						 if(needed == 0)
							 state = States.S_CHECKSUM;
						 break;
					 case States.S_CHECKSUM:
						 if(checksum  == devbuf[nc]) {
							 state = States.S_HEADER;
							 if(cmd < Msp.Cmds.MSPV2 || cmd > Msp.LTM_BASE) {
								 stats.msgs++;
								 var msg = INAVEvent(){cmd=cmd, len=csize, flags=xflags, err=errstate, raw=rxbuf[0:csize+4]};
								 msgq.push(msg);
								 serial_event();
							 }
							 irxbufp = 0;
						 } else {
							 error_counter("MSP %s CRC: ".printf(cmd.to_string()));
							 if(debug) {
								 MWPLog.message("CRC Fail, got %d != %d (cmd=%d)\n",
												devbuf[nc],checksum,cmd);
							 }
							 state = States.S_ERROR;
						 }
						 break;
					 case States.S_END:
						 state = States.S_HEADER;
						 break;

					 case States.S_X_HEADER2:
						 xflags = devbuf[nc];
						 if((devbuf[nc] == readdirn || devbuf[nc] == writedirn || devbuf[nc] == '!')) {
								 if (relaxed)
									 errstate = !(devbuf[nc] == readdirn || devbuf[nc] == writedirn);
								 else
									 errstate = (devbuf[nc] != readdirn); // == '!'
								 state = States.S_X_FLAGS;
						 } else {
							 error_counter("MSP2/Proto");
							 if(debug) {
								 MWPLog.message("fail on header2 %x\n", devbuf[nc]);
							 }
							 state=States.S_ERROR;
						 }
						 break;

					 case States.S_X_FLAGS:
						 checksum ^= devbuf[nc];
						 checksum2 = CRC8.dvb_s2(0, devbuf[nc]);
						 state = States.S_X_ID1;
						 break;
					 case States.S_X_ID1:
						 checksum ^= devbuf[nc];
						 checksum2 = CRC8.dvb_s2(checksum2, devbuf[nc]);
						 xcmd = devbuf[nc];
						 state = States.S_X_ID2;
						 break;
					 case States.S_X_ID2:
						 checksum ^= devbuf[nc];
						 checksum2 = CRC8.dvb_s2(checksum2, devbuf[nc]);
						 xcmd |= (uint16)devbuf[nc] << 8;
						 state = States.S_X_LEN1;
						 break;
					 case States.S_X_LEN1:
						 checksum ^= devbuf[nc];
						 checksum2 = CRC8.dvb_s2(checksum2, devbuf[nc]);
						 csize = devbuf[nc];
						 state = States.S_X_LEN2;
						 break;
					 case States.S_X_LEN2:
						 checksum ^= devbuf[nc];
						 checksum2 = CRC8.dvb_s2(checksum2, devbuf[nc]);
						 csize |= (uint16)devbuf[nc] << 8;
						 needed = csize;
						 if(needed > 0) {
							 check_rxbuf_size();
							 state = States.S_X_DATA;
						 }
						 else
							 state = States.S_X_CHECKSUM;
						 break;
						 case States.S_X_DATA:
							 checksum ^= devbuf[nc];
							 checksum2 = CRC8.dvb_s2(checksum2, devbuf[nc]);
							 rxbuf[irxbufp++] = devbuf[nc];
							 needed--;
							 if(needed == 0)
								 state = States.S_X_CHECKSUM;
							 break;
						 case States.S_X_CHECKSUM:
							 checksum ^= devbuf[nc];
							 if(checksum2  == devbuf[nc]) {
								 state = (encap) ? States.S_CHECKSUM : States.S_HEADER;
								 stats.msgs++;
								 var msg = INAVEvent(){cmd=xcmd, len=csize, flags=xflags, err=errstate, raw=rxbuf[0:csize+4]};
								 msgq.push(msg);
								 serial_event();
								 irxbufp = 0;
							 } else {
								 error_counter("MSP2/CRC");
								 if(debug) {
									 MWPLog.message("X-CRC Fail, got %d != %d (cmd=%d)\n",
													devbuf[nc],checksum,cmd);
								 }
								 state = States.S_ERROR;
							 }
							 break;

						 case States.S_M_SIZE:
							 csize = needed = devbuf[nc];
							 mavsum = MavCRC.crc(0xffff, (uint8)csize);
							 if(needed > 0) {
								 irxbufp= 0;
								 check_rxbuf_size();
							 }
							 state = States.S_M_SEQ;
							 break;
						 case States.S_M_SEQ:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M_ID1;
							 break;
						 case States.S_M_ID1:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M_ID2;
							 break;
						 case States.S_M_ID2:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M_MSGID;
							 break;
						 case States.S_M_MSGID:
							 cmd = (Msp.Cmds)devbuf[nc];
							 mavsum = MavCRC.crc(mavsum, cmd);
							 if (csize == 0)
								 state = States.S_M_CRC1;
							 else
								 state = States.S_M_DATA;
							 break;
						 case States.S_M_DATA:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 rxbuf[irxbufp++] = devbuf[nc];
							 needed--;
							 if(needed == 0)
								 state = States.S_M_CRC1;
							 break;
						 case States.S_M_CRC1:
							 var seed  = MavCRC.lookup(cmd);
							 mavsum = MavCRC.crc(mavsum, seed);
							 irxbufp = 0;
							 rxmavsum = devbuf[nc];
							 state = States.S_M_CRC2;
							 break;
						 case States.S_M_CRC2:
							 var seed  = MavCRC.lookup(cmd);
							 if (seed == 0) { // silently ignore unseeded messages
								 state = States.S_ERROR;
							 } else {
								 rxmavsum |= (devbuf[nc] << 8);
								 if(rxmavsum == mavsum) {
									 stats.msgs++;
									 var msg = INAVEvent(){cmd=cmd+Msp.MAV_BASE, len=csize, flags=0, err=errstate, raw=rxbuf[0:csize+4]};
									 msgq.push(msg);
									 serial_event();
									 state = States.S_HEADER;
								 } else {
									 error_counter("Mav/CRC");
									 if(debug) {
										 MWPLog.message("MAVCRC Fail, got %x != %x (cmd=%u, len=%u)\n",
														rxmavsum, mavsum, cmd, csize);
									 }
									 state = States.S_ERROR;
								 }
							 }
							 break;
						 case States.S_M2_SIZE:
							 csize = needed = devbuf[nc];
							 mavsum = MavCRC.crc(0xffff, (uint8)csize);
							 if(needed > 0) {
								 irxbufp= 0;
								 check_rxbuf_size();
							 }
							 state = States.S_M2_FLG1;
							 break;
						 case States.S_M2_FLG1:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 if((devbuf[nc] & 1) == 1)
								 mavsig = 13;
							 else
								 mavsig = 0;
							 state = States.S_M2_FLG2;
							 break;
						 case States.S_M2_FLG2:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M2_SEQ;
							 break;
						 case States.S_M2_SEQ:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M2_ID1;
							 break;
						 case States.S_M2_ID1:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M2_ID2;
							 break;
						 case States.S_M2_ID2:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M2_MSGID0;
							 break;
						 case States.S_M2_MSGID0:
							 cmd = (Msp.Cmds)devbuf[nc];
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M2_MSGID1;
							 break;

						 case States.S_M2_MSGID1:
							 cmd |= (Msp.Cmds)(devbuf[nc] << 8);
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 state = States.S_M2_MSGID2;
							 break;

						 case States.S_M2_MSGID2:
							 cmd |= (Msp.Cmds)(devbuf[nc] << 16);
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 if (csize == 0)
								 state = States.S_M2_CRC1;
							 else
								 state = States.S_M2_DATA;
							 break;
						 case States.S_M2_DATA:
							 mavsum = MavCRC.crc(mavsum, devbuf[nc]);
							 rxbuf[irxbufp++] = devbuf[nc];
							 needed--;
							 if(needed == 0)
								 state = States.S_M2_CRC1;
							 break;
						 case States.S_M2_CRC1:
							 var seed  = MavCRC.lookup(cmd);
							 mavsum = MavCRC.crc(mavsum, seed);
							 irxbufp = 0;
							 rxmavsum = devbuf[nc];
							 state = States.S_M2_CRC2;
							 break;
						 case States.S_M2_CRC2:
							 rxmavsum |= (devbuf[nc] << 8);
							 if(rxmavsum == mavsum) {
								 stats.msgs++;
								 var mcmd = cmd+Msp.MAV_BASE;
								 var mmsize = MavSize.find_size(mcmd);
								 if (mmsize ==  0) {
									 mmsize = csize+128;
								 }
								 mmsize = uint32.min(1024, mmsize);
								 // Mav2 nul supression
								 for(var j = csize; j < mmsize; j++) {
									 rxbuf[j] = 0;
								 }

								 var msg = INAVEvent(){cmd=mcmd, len=csize, flags=0, err=errstate, raw=rxbuf[0:mmsize]};
								 msgq.push(msg);
								 serial_event();
								 if(mavsig == 0)
									 state = States.S_HEADER;
								 else
									 state = States.S_M2_SIG;
							 } else {
								 error_counter("Mav2/CRC");
								 if(debug) {
									 MWPLog.message("MAVCRC2 Fail, got %x != %x (cmd=%u, len=%u)\n",
													rxmavsum, mavsum, cmd, csize);
								 }
								 state = States.S_ERROR;
							 }
							 break;
					 case States.S_M2_SIG:
						 mavsig--;
						 if (mavsig == 0)
							 state = States.S_HEADER;
						 break;
					 default:
						 break; // S_M_STX, S_M2_STX
					 }
				 }
			 }
		 }
		 return true;
	 }

	 private ssize_t io_write(uint8[]buf, size_t count) {
		 ssize_t sz;
		 size_t ssz;
		 sz = -1;
		 try {
			 if((commode & ComMode.UDP) != 0) {
				 sz = socket.send_to(sockaddr, buf[:count]);
			 } else if ((commode & ComMode.TTY) == ComMode.TTY) {
#if !WINDOWS
				 sz = MwpSerial.write(wrfd, buf, count);
#else
				 dos.write_all (buf, out ssz, null);
				 sz = (ssize_t)ssz;
#endif
			 } else if ((commode & ComMode.BT) == ComMode.BT) {
				 sz = Posix.write(wrfd, buf[:count], count);
			 } else {
				 var iostat = io_chan.write_chars((char[])buf[:count], out ssz);
				 sz = (ssize_t)ssz;
				 if(iostat != IOStatus.NORMAL) {
					 stderr.printf("IOSTAT write fails: %s\n", iostat.to_string());
						 return -1;
				 }
			 }
		 } catch (Error e) {
			 stderr.printf("Write fails: %s\n", e.message);
			 sz = -1;
		 }
		 return sz;
	 }

	 private ssize_t stream_writer(uint8[]buf, size_t count) {
		 ssize_t tsz;
		 ssize_t sz;
		 tsz = 0;
		 uint j = 0;
		 for(uint n = (uint)count; n > 0; ) {
			 var nc = (n > WEAKSIZE) ? WEAKSIZE : n;
			 sz = io_write(buf[j:j+nc], nc);
			 if (sz == -1) {
				 return -1;
			 }
			 tsz += sz;
			 j += nc;
			 n -= nc;
		 }
		 return tsz;
	 }

	 public ssize_t write(uint8[]buf, size_t count) {
		 ssize_t sz = -1;
		 if(available) {
			 if((commode & ComMode.WEAKBLE) == ComMode.WEAKBLE) {
				 sz = stream_writer(buf, count);
			 } else {
				 sz = io_write(buf, count);
			 }
			 stats.txbytes += sz;
		 }
		 if(rawlog) {
			 log_raw('o', buf, (int)count);
		 }
		 if(sz < 0) {
			 close();
		 }
		 return sz;
	 }

	 public void send_ltm(uint8 cmd, void *data, size_t len) {
		 if(available == true && !ro) {
			 if(len != 0 && data != null) {
				 check_txbuf_size(len+4);
				 var nb = generate_ltm(cmd, data, len, ref txbuf);
				 write(txbuf, nb);
			 }
		 }
	 }

	 public void send_mav(uint16 cmd, void *data, size_t len) {
		 if(available == true && !ro) {
			 size_t nb = 0;
			 check_txbuf_size(len+12);
			 if(mavvid == 2 || cmd > 256) {
				 nb = generate_mav2(cmd, data, len, mavseqno, mavsysid, ref txbuf);
			 } else {
				 nb = generate_mav1(cmd, data, len, mavseqno, mavsysid, ref txbuf);
			 }
			 write(txbuf, nb);
			 mavseqno++;
		 }
	 }

	 public static size_t generate_ltm(uint8 cmd, void *data, size_t len, ref uint8[] _txbuf) {
		 uint8 *ptx = _txbuf;
		 uint8* pdata = (uint8*)data;
		 uint8 ck = 0;
		 *ptx++ ='$';
		 *ptx++ = 'T';
		 *ptx++ = cmd;
		 for(var i = 0; i < len; i++) {
			 *ptx = *pdata++;
			 ck ^= *ptx++;
		 }
		 *ptx++ = ck;
		 return (ptx - (uint8*)_txbuf);
	 }

	 public static size_t generate_mav2(uint16 cmd, void *data, size_t len,
										uint8 _mavseqno, uint8 _mavsysid,
										ref uint8[] _txbuf) {
		 uint16 mcrc;
		 uint8* ptx = _txbuf;
		 uint8* pdata = data;

		 // Mav2 null supression
		 while (len > 1 && pdata[len-1] == 0) {
			 len--;
		 }
		 mcrc = MavCRC.crc(0xffff, (uint8)len);

		 *ptx++ = 0xfd;           // STX
		 *ptx++ = (uint8)len;     // len

		 *ptx++ = 0;              // incomp
		 mcrc = MavCRC.crc(mcrc, 0);
		 *ptx++ = 0;             // comp
		 mcrc = MavCRC.crc(mcrc, 0);

		 *ptx++ = _mavseqno;     // seqno
		 mcrc = MavCRC.crc(mcrc, _mavseqno);

		 *ptx++ = _mavsysid;     // sysid
		 mcrc = MavCRC.crc(mcrc, _mavsysid);
		 *ptx++ = MAVID2;        // compid
		 mcrc = MavCRC.crc(mcrc, MAVID2);

		 uint8 c = (uint8)(cmd & 0xff);
		 *ptx++ = c;  // id0
		 mcrc = MavCRC.crc(mcrc, c);

		 c = (uint8)(cmd >> 8);
		 *ptx++ = c; // id1
		 mcrc = MavCRC.crc(mcrc, c);

		 c = 0;
		 *ptx++ = c; // id2
		 mcrc = MavCRC.crc(mcrc, c);

		 for(var j = 0; j < len; j++) {
			 *ptx = *pdata++;
			 mcrc = MavCRC.crc(mcrc, *ptx);
			 ptx++;
		 }
		 var seed  = MavCRC.lookup(cmd);
		 mcrc = MavCRC.crc(mcrc, seed);
		 *ptx++ = (uint8)(mcrc&0xff); // crc
		 *ptx++ = (uint8)(mcrc >> 8); // crc
		 return (ptx - (uint8*)_txbuf);
	 }

	 public static size_t generate_mav1(uint16 cmd, void *data, size_t len,
										uint8 _mavseqno, uint8 _mavsysid,
										ref uint8[] _txbuf) {
		 uint16 mcrc;
		 uint8* ptx = _txbuf;
		 uint8* pdata = data;

		 mcrc = MavCRC.crc(0xffff, (uint8)len);

		 *ptx++ = 0xfe;
		 *ptx++ = (uint8)len;

		 *ptx++ = _mavseqno;
		 mcrc = MavCRC.crc(mcrc, _mavseqno);
		 *ptx++ = _mavsysid;
		 mcrc = MavCRC.crc(mcrc, _mavsysid);
		 *ptx++ = MAVID2;
		 mcrc = MavCRC.crc(mcrc, MAVID2);
		 *ptx++ = (uint8)cmd;
		 mcrc = MavCRC.crc(mcrc, (uint8)cmd);
		 for(var j = 0; j < len; j++) {
			 *ptx = *pdata++;
			 mcrc = MavCRC.crc(mcrc, *ptx);
			 ptx++;
		 }
		 var seed  = MavCRC.lookup(cmd);
		 mcrc = MavCRC.crc(mcrc, seed);
		 *ptx++ = (uint8)(mcrc&0xff);
		 *ptx++ = (uint8)(mcrc >> 8);
		 return (ptx - (uint8*)_txbuf);
	 }

	 public static size_t generate_v1(uint8 cmd, void *data, size_t len, char _writed, ref uint8[] _txbuf) {
		 uint8 ck = 0;
		 uint8* ptx = _txbuf;
		 uint8* pdata = data;

		 *ptx++ = '$';
		 *ptx++ = 'M';
		 *ptx++ = _writed;
		 ck ^= (uint8)len;
		 *ptx++ = (uint8)len;
		 ck ^=  cmd;
		 *ptx++ = cmd;
		 for(var i = 0; i < len; i++) {
			 *ptx = *pdata++;
			 ck ^= *ptx++;
		 }
		 *ptx  = ck;
		 return len+6;
	 }

	 public static size_t generate_v2(uint16 cmd, void *data, size_t len, char _writed, ref uint8[] _txbuf) {
		 uint8 ck2=0;

		 uint8* ptx = _txbuf;
		 uint8* pdata = data;

		 *ptx++ ='$';
		 *ptx++ ='X';
		 *ptx++ = _writed;
		 *ptx++ = 0; // flags
		 ptx = SEDE.serialise_u16(ptx, cmd);
		 ptx = SEDE.serialise_u16(ptx, (uint16)len);
		 ck2 = CRC8.dvb_s2(ck2, _txbuf[3]);
		 ck2 = CRC8.dvb_s2(ck2, _txbuf[4]);
		 ck2 = CRC8.dvb_s2(ck2, _txbuf[5]);
		 ck2 = CRC8.dvb_s2(ck2, _txbuf[6]);
		 ck2 = CRC8.dvb_s2(ck2, _txbuf[7]);

		 for (var i = 0; i < len; i++) {
			 *ptx = *pdata++;
			 ck2 = CRC8.dvb_s2(ck2, *ptx);
			 ptx++;
		 }
		 *ptx = ck2;
		 return len+9;
	 }

	 public size_t send_command(uint16 cmd, void *data, size_t len, bool sim=false) {
		 if(available == true && !ro) {
			 char tmp = writedirn;
			 if (sim) // forces SIM mode (inav-radar)
				 tmp = '>';
			 size_t mlen;
			 if(use_v2 || cmd > 254 || len > 254)
				 mlen = generate_v2(cmd,data,len, tmp, ref txbuf);
			 else
				 mlen  = generate_v1((uint8)cmd, data, len, tmp, ref txbuf);

			 return write(txbuf, mlen);
		 } else {
			 return -1;
		 }
	 }

	 public void send_error(uint8 cmd) {
		 if(available == true && !ro) {
			 uint8 dstr[8] = {'$', 'M', '!', 0, cmd, cmd};
			 write(dstr, 6);
		 }
	 }

	 private void log_raw(uint8 dirn, uint8[] buf, int len) {
		 MwpRaw.Header hdr = MwpRaw.Header(){};
		 hdr.s.et = timer.elapsed();
		 hdr.s.len = (uint16)len;
		 hdr.s.dirn = dirn;
		 raws.write(hdr.bytes);
		 raws.write(buf[:len]);
	 }

	 public void raw_logging(bool state) {
		 if(state == true) {
			 time_t currtime;
			 time_t(out currtime);
			 string dstr = devname.delimit("""\:@/[]?=""", '_');
			 var dt = new DateTime.from_unix_local(currtime);
			 var logdir = UserDirs.get_default();
			 var fn  = "mwp.%s.%s.raw".printf(dstr, dt.format("%FT%H%M%S"));
			 var lfn = Path.build_filename(logdir, fn);
			 MWPLog.message("raw log for %s %s\n", devname, lfn);
			 raws = FileStream.open (lfn, "wb");
			 raws.write("v2\n".data);
			 rawlog = true;
			 timer = new Timer();
		 } else {
			 raws.flush();
			 raws = null;
			 timer.stop();
			 rawlog = false;
		 }
	 }

	 public void dump_raw_data (uint8[]buf, int len) {
		 for(var nc = 0; nc < len; nc++) {
			 if(buf[nc] == '$')
				 MWPLog.message("\n");
			 stderr.printf("%02x ", buf[nc]);
		 }
		 stderr.printf("(%d) ",len);
	 }

	 public void set_mode(Mode mode) {
		 if (mode == Mode.NORMAL) {
			 readdirn='>';
			 writedirn= '<';
		 } else {
			 readdirn='<';
			 writedirn= '>';
		 }
	 }

	 public void set_relaxed(bool _rlx) {
		 relaxed = _rlx;
	 }

	 public static string format_condition(IOCondition cond) {
		 string [] conds = {};
		 if(IOCondition.IN in cond) {
			 conds += "IN";
		 }
		 if(IOCondition.OUT in cond) {
			 conds += "OUT";
		 }
		 if(IOCondition.PRI in cond) {
			 conds += "PRI";
		 }
		 if(IOCondition.ERR in cond) {
			 conds += "ERR";
		 }
		 if(IOCondition.HUP in cond) {
			 conds += "HUP";
		 }
		 if(IOCondition.NVAL in cond) {
			 conds += "NVAL";
		 }
		 if(conds.length > 0) {
			 return string.joinv(" ", conds);
		 } else {
			 return "";
		 }
	 }
 }
