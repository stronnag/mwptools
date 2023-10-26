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
        HOME_DIST  = 0x0420
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

    uint8 dvb_s2(uint8 crc, uint8 a) {
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
    private IOChannel io_read;
    private Socket skt;
    private SocketAddress sockaddr;
    public  States state {private set; get;}
    private uint8 xflags;
    private uint8 checksum;
    private uint8 checksum2;
    private uint16 csize;
    private uint16 needed;
    private uint16 xcmd;
    private MSP.Cmds cmd;
    private int irxbufp;
    private uint16 rxbuf_alloc;
    private uint16 txbuf_alloc = 256;
    private uint8 []rxbuf;
    private uint8 []txbuf;
    public bool available {private set; get;}
    public bool force4 = false;
    private uint tag;
    private char readdirn {set; get; default= '>';}
    private char writedirn {set; get; default= '<';}
    private bool errstate;
    private int commerr;
    private bool rawlog;
    private int raws;
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
	private DevMask dtype;
	public static bool debug;

	public enum MemAlloc {
        RX=1024,
        TX=256,
        DEV=2048
    }

    public enum ComMode {
        TTY=1,
        STREAM=2,
        FD=4,
        BT=8
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

    public signal void serial_event (MSP.Cmds event, uint8[]result, uint len, uint8 flags, bool err);
    public signal void cli_event(uint8[]raw, uint len);
    public signal void serial_lost ();
    public signal void sport_event(uint32 a, uint32 b);
    public signal void flysky_event(uint8[]buf);
    public signal void crsf_event(uint8[]raw);

    public static PMask name_to_pmask(string name) {
        switch(name.down()) {
        case "inav":
        case "1":
            return PMask.INAV;
        case "sport":
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

	public void set_dmask(DevMask dm) {
		dtype = dm;
	}
	public DevMask get_dmask() {
		return dtype;
	}

	public int randomUDP(int[] res) {
        int result = -1;
        setup_ip(null,0);
        if (fd > -1) {
            try {
                commode = 0;
                var xsa = skt.get_local_address();
                var outp = ((InetSocketAddress)xsa).get_port();
                res[0] = fd;
                res[1] = (int)outp;
                result = 0;
                available = true;
                devname = "udp #%d".printf(outp);
                setup_reader();
            } catch {}
        }
        return result;
    }

    public string get_devname() {
        return devname;
    }

    public MWSerial.forwarder() {
        fwd = true;
        available = false;
        set_txbuf(MemAlloc.TX);
		pmask = PMask.AUTO;
    }

    public MWSerial.reader() {
        available = fwd = false;
        ro = true;
        rxbuf_alloc = MemAlloc.RX;
        rxbuf = new uint8[rxbuf_alloc];
        devbuf = new uint8[MemAlloc.DEV];
		pmask = PMask.AUTO;
    }

    public MWSerial() {
        fwd =  available = false;
        rxbuf_alloc = MemAlloc.RX;
        rxbuf = new uint8[rxbuf_alloc];
        txbuf = new uint8[txbuf_alloc];
        devbuf = new uint8[MemAlloc.DEV];
		pmask = PMask.AUTO ;
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
        stats =  {0.0, 0, 0, 0.0, 0.0};
    }

    private void setup_fd (uint rate) {
        if((commode & ComMode.TTY) == ComMode.TTY) {
            baudrate = rate;
            MwpSerial.set_speed(fd, (int)rate, null);
        }
        available = true;
        setup_reader();
    }

    public void setup_reader() {
        clear_counters();
        state = States.S_HEADER;
        try {
            io_read = new IOChannel.unix_new(fd);
            if(io_read.set_encoding(null) != IOStatus.NORMAL)
				error("Failed to set encoding");
            tag = io_read.add_watch(IOCondition.IN|IOCondition.HUP|
                                    IOCondition.NVAL|IOCondition.ERR,
                                    device_read);

        } catch(IOChannelError e) {
            error("IOChannel: %s", e.message);
        }
    }

    private void setup_ip(string? host, uint16 port, string? rhost=null, uint16 rport = 0) {
        if(MwpMisc.is_cygwin())
            force4 = true;

        fd = -1;
        baudrate = 0;
        if((host == null || host.length == 0) &&
           ((commode & ComMode.STREAM) != ComMode.STREAM)) {
            try {
                SocketFamily[] fams = {};
                if(!force4)
                    fams += SocketFamily.IPV6;
                fams += SocketFamily.IPV4;
                foreach(var fam in fams) {
                    var sa = new InetSocketAddress (new InetAddress.any(fam),
                                                    (uint16)port);
                    skt = new Socket (fam, SocketType.DATAGRAM, SocketProtocol.UDP);
                    if (skt != null) {
                        skt.bind (sa, true);
                        fd = skt.fd;
						if(debug) {
							MWPLog.message("bound: %s %d %d\n", fam.to_string(), fd, port);
						}
                        break;
                    }
                }
                if(rhost != null && rport != 0) {
                    var resolver = Resolver.get_default ();
                    var addresses = resolver.lookup_by_name (rhost, null);
                    var addr0 = addresses.nth_data (0);
                    sockaddr = new InetSocketAddress(addr0,rport);
                }
            } catch (Error e) {
                MWPLog.message ("binder: %s\n", e.message);
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

                        if((commode & ComMode.STREAM) == ComMode.STREAM) {
                            stype = SocketType.STREAM;
                            sproto = SocketProtocol.TCP;
                        } else {
                            stype = SocketType.DATAGRAM;
                            sproto = SocketProtocol.UDP;
                        }
                        skt = new Socket (fam, stype, sproto);
                        if(skt != null) {
                            fd = skt.fd;
                            if(fd != -1) {
                                try {
                                    if (sproto != SocketProtocol.UDP)
                                        skt.connect(sockaddr);
                                    set_noblock();
                                } catch (Error e) {
                                    MWPLog.message("connection fails %s\n", e.message);
                                    skt.close();
                                    fd = -1;
                                }
                            }
                            break;
                        }
                    }
                }
            } catch(Error e) {
                MWPLog.message("client socket: %s %d: %s\n", host, port, e.message);
                if (fd > 0)
                    try { skt.close(); } catch {}
                fd = -1;
            }
        }
    }

    private void set_noblock() {
        Posix.fcntl(fd, Posix.F_SETFL, Posix.fcntl(fd, Posix.F_GETFL, 0) | Posix.O_NONBLOCK);
    }

/*
  public bool open_sport(string device, out string estr) {
  fwd = false;
  MWPLog.message("SPORT: open %s\n", device);
  return open(device, 0, out estr);
  }
*/
	public void get_error_message(out string estr) {
		estr = "";
		uint8 [] sbuf = new uint8[1024];
		var s = MwpSerial.error_text(lasterr, sbuf, 1024);
		estr = "%s %s (%d)".printf(devname, s,lasterr);
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
            if(fwd == false)
                setup_reader();
            else
                set_noblock();
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


	public async bool gatt_async (GattClient gc) {
        var thr = new Thread<bool> ("mwp-ble", () => {
                        gc.bridge();
                        Idle.add (gatt_async.callback);
                        return true;
                });
        yield;
        return thr.join();
	}

	public bool open_w (string _device, uint rate) {
		string device;
        int n;
		if((n = _device.index_of_char(' ')) == -1) {
			device = _device;
		} else {
			device = _device.substring(0,n);
		}
		devname = device;
		print_raw = (Environment.get_variable("MWP_PRINT_RAW") != null);
		commode = 0;

		if(device.length == 17 && device[2] == ':' && device[5] == ':' && device[8] == ':' && device[11] == ':' && device[14] == ':') {
			int dmask = 0;
			int ncnt = 0;
			while (( dmask = DevManager.get_type_for_name(device)) == 0) {
				Thread.usleep(1000);
				ncnt += 1;
				if(ncnt > 5000)
					break;
			}
			if (dmask == 0) {
				fd = -1;
				available = false;
				lasterr = Posix.ETIMEDOUT;
				return false;
			}

			if(dmask == DevMask.BT) {
				fd = BTSocket.connect(device, &lasterr);
				if (fd != -1) {
					commode = ComMode.FD|ComMode.STREAM|ComMode.BT;
					set_noblock();
				}
			} else {
				int status = 0;
				var gc = new GattClient (device, out status);
				if (gc != null) {
					unowned var gatdev = gc.get_devnode();
					MWPLog.message("Mapping GATT channels to %s\n", gatdev);
					commode = ComMode.STREAM|ComMode.TTY;
					fd = MwpSerial.open(gatdev, (int)rate);
					gatt_async.begin(gc, (obj,res) => {
							gatt_async.end(res);
							gc = null;
						});
				} else {
					stderr.printf("BLE Fails, %d\n", status);
					fd = -1;
					available = false;
					lasterr = Posix.ETIMEDOUT;
					return false;
				}
			}
		} else {
			var u = UriParser.parse(device);
			if (u != null) {
				string host = null;
				uint16 port = 0;
				string remhost = null;
				uint16 remport = 0;
				if(u.scheme == "tcp") {
					commode = ComMode.STREAM;
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

				if (u.query != null) {
					var parts = u.query.split("=");
					if(parts.length == 2 && parts[0]=="bind") {
						remhost = u.host;
						remport = (uint16)u.port;
						port = (uint16)int.parse(parts[1]);
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
				commode = ComMode.STREAM|ComMode.TTY;
				var parts = device.split ("@");
				if(parts.length == 2) {
					device  = parts[0];
					rate = int.parse(parts[1]);
				}
				fd = MwpSerial.open(device, (int)rate);
			}
		}
		lasterr=Posix.errno;
		if(fd < 0) {
			fd = -1;
			available = false;
		} else {
			available = true;
		}
		return available;
    }

    public bool open_fd(int _fd, int rate, bool rawfd = false) {
        devname = "fd #%d".printf(_fd);
        fd = _fd;
        fwd =  false;
        if(rate != -1)
            commode = ComMode.TTY|ComMode.STREAM;
        if(rawfd)
            commode = ComMode.FD|ComMode.STREAM;
        setup_fd(rate);
        return available;
    }

    ~MWSerial() {
        if(fd != -1)
            close();
    }

    public void close() {
        available=false;
        if(fd != -1) {
            if(tag > 0) {
                Source.remove(tag);
                tag = 0;
            }
            if((commode & ComMode.TTY) == ComMode.TTY) {
                MwpSerial.close(fd);
                fd = -1;
            }
            else if ((commode & ComMode.FD) == ComMode.FD)
                Posix.close(fd);
            else {
                if (!skt.is_closed()) {
                    try {
                        skt.close();
                    } catch (Error e) {
                        warning ("sock close %s", e.message);
                    }
                }
                sockaddr=null;
            }
            fd = -1;
        }
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

    private void show_cond(IOCondition cond) {
        StringBuilder sb = new StringBuilder("");
        sb.append_printf("Close %s : ", devname);
        sb.append_c(' ');
        for(var j = 0; j < 8; j++) {
            IOCondition n = (IOCondition)(1 << j);
            if((cond & n) == n) {
                sb.append(n.to_string());
                sb.append_c('|');
            }
        }
        sb.truncate(sb.len-1);
        sb.append_printf(" (%x)\n", cond);
        MWPLog.message(sb.str);
    }

	private bool fr_publish(uint8 []buf) {
		bool res = SportDev.fr_checksum(buf);
		if(res) {
			ushort id;
			uint val;
			SEDE.deserialise_u16(&buf[2], out id);
			SEDE.deserialise_u32(&buf[4], out val);
			sport_event((uint32)id,val);
		}
		return res;
	}

    private bool device_read(IOChannel gio, IOCondition cond) {
        ssize_t res = 0;

        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0) {
            show_cond(cond);
            available = false;
            if(fd != -1)
                serial_lost();
            tag = 0; // REMOVE will remove the iochannel watch
            return Source.REMOVE;
        } else if (fd != -1 && (cond & IOCondition.IN) != 0) {
            if((commode & ComMode.BT) == ComMode.BT) {
                res = Posix.recv(fd,devbuf,MemAlloc.DEV,0);
                if(res == 0)
                    return Source.CONTINUE;
            } else if((commode & ComMode.STREAM) == ComMode.STREAM) {
                res = Posix.read(fd,devbuf,MemAlloc.DEV);
                if(res == 0) {
                    if((commode & ComMode.TTY) != ComMode.TTY)
                        serial_lost();
                    return Source.CONTINUE;
                }
            } else {
                try {
                    res = skt.receive_from(out sockaddr, devbuf);
                } catch(Error e) {
                    res = 0;
                }
            }

            if(pmode == ProtoMode.CLI) {
                csize = (uint16)res;
                cli_event(devbuf, csize);
            } else {
                if(stime == 0)
                    stime =  GLib.get_monotonic_time();
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
							flysky_event(MPM.get_buffer());
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
								}
								break;
							case 0xfd:
								if ((pmask & PMask.INAV) == PMask.INAV) {
									sp = nc;
									state=States.S_M2_SIZE;
									errstate = false;
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
									crsf_event(CRSF.crsf_buffer);
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
								cmd = MSP.Cmds.TG_FRAME;
								break;
							case 'A':
								needed = (uint16) MSize.LTM_AFRAME;
								cmd = MSP.Cmds.TA_FRAME;
								break;
							case 'S':
								needed = (uint16) MSize.LTM_SFRAME;
								cmd = MSP.Cmds.TS_FRAME;
								break;
							case 'O':
								needed = (uint16) MSize.LTM_OFRAME;
								cmd = MSP.Cmds.TO_FRAME;
								break;
							case 'N':
								needed = (uint16) MSize.LTM_NFRAME;
								cmd = MSP.Cmds.TN_FRAME;
								break;
							case 'X':
								needed = (uint16) MSize.LTM_XFRAME;
								cmd = MSP.Cmds.TX_FRAME;
								break;
								// Lower case are 'private'
							case 'q':
								needed = 2;
								cmd = MSP.Cmds.Tq_FRAME;
								break;
							case 'a':
								needed = 2;
								cmd = MSP.Cmds.Ta_FRAME;
								break;
							case 'r':
								needed = 8;
								cmd = MSP.Cmds.Tr_FRAME;
								break;
							case 'x':
								needed = 1;
								cmd = MSP.Cmds.Tx_FRAME;
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
							cmd = (MSP.Cmds)devbuf[nc];
							checksum ^= cmd;
							if(cmd == MSP.Cmds.MSPV2) {
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
								stats.msgs++;
								if(cmd < MSP.Cmds.MSPV2 || cmd > MSP.Cmds.LTM_BASE)
									serial_event(cmd, rxbuf, csize, xflags, errstate);
								irxbufp = 0;
							} else {
								error_counter("MSP/CRC");
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
								serial_event((MSP.Cmds)xcmd, rxbuf, csize, xflags, errstate);
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
							mavsum = mavlink_crc(0xffff, (uint8)csize);
							if(needed > 0) {
								irxbufp= 0;
								check_rxbuf_size();
							}
							state = States.S_M_SEQ;
							break;
						case States.S_M_SEQ:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M_ID1;
							break;
						case States.S_M_ID1:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M_ID2;
							break;
						case States.S_M_ID2:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M_MSGID;
							break;
						case States.S_M_MSGID:
							cmd = (MSP.Cmds)devbuf[nc];
							mavsum = mavlink_crc(mavsum, cmd);
							if (csize == 0)
								state = States.S_M_CRC1;
							else
								state = States.S_M_DATA;
                            break;
						case States.S_M_DATA:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							rxbuf[irxbufp++] = devbuf[nc];
							needed--;
							if(needed == 0)
								state = States.S_M_CRC1;
							break;
						case States.S_M_CRC1:
							var seed  = MavCRC.lookup(cmd);
							mavsum = mavlink_crc(mavsum, seed);
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
									serial_event (cmd+MSP.Cmds.MAV_BASE, rxbuf, csize, 0, errstate);
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
							mavsum = mavlink_crc(0xffff, (uint8)csize);
							if(needed > 0) {
								irxbufp= 0;
								check_rxbuf_size();
							}
							state = States.S_M2_FLG1;
							break;
						case States.S_M2_FLG1:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							if((devbuf[nc] & 1) == 1)
								mavsig = 13;
							else
								mavsig = 0;
							state = States.S_M2_FLG2;
							break;
						case States.S_M2_FLG2:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M2_SEQ;
							break;
						case States.S_M2_SEQ:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M2_ID1;
							break;
						case States.S_M2_ID1:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M2_ID2;
							break;
						case States.S_M2_ID2:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M2_MSGID0;
							break;
						case States.S_M2_MSGID0:
							cmd = (MSP.Cmds)devbuf[nc];
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M2_MSGID1;
							break;

						case States.S_M2_MSGID1:
							cmd |= (MSP.Cmds)(devbuf[nc] << 8);
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							state = States.S_M2_MSGID2;
							break;

						case States.S_M2_MSGID2:
							cmd |= (MSP.Cmds)(devbuf[nc] << 16);
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							if (csize == 0)
								state = States.S_M2_CRC1;
							else
								state = States.S_M2_DATA;
							break;
						case States.S_M2_DATA:
							mavsum = mavlink_crc(mavsum, devbuf[nc]);
							rxbuf[irxbufp++] = devbuf[nc];
							needed--;
							if(needed == 0)
								state = States.S_M2_CRC1;
							break;
						case States.S_M2_CRC1:
							var seed  = MavCRC.lookup(cmd);
							mavsum = mavlink_crc(mavsum, seed);
							irxbufp = 0;
							rxmavsum = devbuf[nc];
							state = States.S_M2_CRC2;
							break;
						case States.S_M2_CRC2:
							rxmavsum |= (devbuf[nc] << 8);
							if(rxmavsum == mavsum) {
								stats.msgs++;
								serial_event (cmd+MSP.Cmds.MAV_BASE,
											  rxbuf, csize, 0, errstate);
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
		}
		return Source.CONTINUE;
	}

	public uint16 mavlink_crc(uint16 acc, uint8 val) {
		uint8 tmp;
		tmp = val ^ (uint8)(acc&0xff);
		tmp ^= (tmp<<4);
		acc = (acc>>8) ^ (tmp<<8) ^ (tmp<<3) ^ (tmp>>4);
		return acc;
	}

	public ssize_t write(void *buf, size_t count) {
		ssize_t size;
		if(ro)
			return 0;

		if(stime == 0 && pmode == ProtoMode.NORMAL)
			stime =  GLib.get_monotonic_time();

		stats.txbytes += count;

		if((commode & ComMode.BT) == ComMode.BT)
			size = Posix.send(fd, buf, count, 0);
		else if((commode & ComMode.STREAM) == ComMode.STREAM)
			size = Posix.write(fd, buf, count);
		else {
			unowned uint8[] sbuf = (uint8[]) buf;
			sbuf.length = (int)count;
			try {
				size = skt.send_to (sockaddr, sbuf);
			} catch(Error e) {
//                stderr.printf("err::send: %s", e.message);
				size = 0;
			}
		}
		if(rawlog == true) {
			log_raw('o',buf,(int)count);
		}
		return size;
	}

	public void send_ltm(uint8 cmd, void *data, size_t len) {
		if(available == true && !ro) {
			if(len != 0 && data != null) {
				uint8 *ptx = txbuf;
				uint8* pdata = (uint8*)data;
				check_txbuf_size(len+4);
				uint8 ck = 0;
				*ptx++ ='$';
				*ptx++ = 'T';
				*ptx++ = cmd;
				for(var i = 0; i < len; i++) {
					*ptx = *pdata++;
					ck ^= *ptx++;
				}
				*ptx = ck;
				write(txbuf, (len+4));
			}
		}
	}

	public void send_mav(uint8 cmd, void *data, size_t len) {
		const uint8 MAVID1='j';
		const uint8 MAVID2='h';

		if(available == true && !ro) {
			uint16 mcrc;
			uint8* ptx = txbuf;
			uint8* pdata = data;

			check_txbuf_size(len+8);
			mcrc = mavlink_crc(0xffff, (uint8)len);

			*ptx++ = 0xfe;
			*ptx++ = (uint8)len;

			*ptx++ = mavseqno;
			mcrc = mavlink_crc(mcrc, mavseqno);
			mavseqno++;
			*ptx++ = MAVID1;
			mcrc = mavlink_crc(mcrc, MAVID1);
			*ptx++ = MAVID2;
			mcrc = mavlink_crc(mcrc, MAVID2);
			*ptx++ = cmd;
			mcrc = mavlink_crc(mcrc, cmd);
			for(var j = 0; j < len; j++) {
				*ptx = *pdata++;
				mcrc = mavlink_crc(mcrc, *ptx);
				ptx++;
			}
			var seed  = MavCRC.lookup(cmd);
			mcrc = mavlink_crc(mcrc, seed);
			*ptx++ = (uint8)(mcrc&0xff);
			*ptx++ = (uint8)(mcrc >> 8);
			write(txbuf, (len+8));
		}
	}

	private size_t generate_v1(uint8 cmd, void *data, size_t len) {
		uint8 ck = 0;

		check_txbuf_size(len+6);
		uint8* ptx = txbuf;
		uint8* pdata = data;

		*ptx++ = '$';
		*ptx++ = 'M';
		*ptx++ = writedirn;
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

	public size_t generate_v2(uint16 cmd, void *data, size_t len) {
		uint8 ck2=0;

		check_txbuf_size(len+9);

		uint8* ptx = txbuf;
		uint8* pdata = data;

		*ptx++ ='$';
		*ptx++ ='X';
		*ptx++ = writedirn;
		*ptx++ = 0; // flags
		ptx = SEDE.serialise_u16(ptx, cmd);
		ptx = SEDE.serialise_u16(ptx, (uint16)len);
		ck2 = CRC8.dvb_s2(ck2, txbuf[3]);
		ck2 = CRC8.dvb_s2(ck2, txbuf[4]);
		ck2 = CRC8.dvb_s2(ck2, txbuf[5]);
		ck2 = CRC8.dvb_s2(ck2, txbuf[6]);
		ck2 = CRC8.dvb_s2(ck2, txbuf[7]);

		for (var i = 0; i < len; i++) {
			*ptx = *pdata++;
			ck2 = CRC8.dvb_s2(ck2, *ptx);
			ptx++;
		}
		*ptx = ck2;
		return len+9;
	}

	public void send_command(uint16 cmd, void *data, size_t len, bool sim=false) {
		if(available == true && !ro) {
			char tmp = writedirn;
			if (sim) // forces SIM mode (inav-radar)
				writedirn = '>';
			size_t mlen;
			if(use_v2 || cmd > 254 || len > 254)
				mlen = generate_v2(cmd,data,len);
			else
				mlen  = generate_v1((uint8)cmd, data, len);
			writedirn = tmp;
			write(txbuf, mlen);
		}
	}

	public void send_error(uint8 cmd) {
		if(available == true && !ro) {
			uint8 dstr[8] = {'$', 'M', '!', 0, cmd, cmd};
			write(dstr, 6);
		}
	}

	private void log_raw(uint8 dirn, void *buf, int len) {
		double dt = timer.elapsed ();
		uint16 blen = (uint16)len;
		Posix.write(raws, &dt, sizeof(double));
		Posix.write(raws, &blen, 2);
		Posix.write(raws, &dirn, 1);
		Posix.write(raws, buf,len);
	}

	public void raw_logging(bool state) {
		if(state == true) {
			time_t currtime;
			time_t(out currtime);
			string dstr = devname.delimit("""\:@/[]""", '_');
			var fn  = "mwp.%s.%s.raw".printf(dstr, Time.local(currtime).format("%FT%H%M%S"));
			MWPLog.message("raw log for %s %s\n", devname, fn);
			raws = Posix.open (fn, Posix.O_TRUNC|Posix.O_CREAT|Posix.O_WRONLY, 0640);
			timer = new Timer ();
			rawlog = true;
			Posix.write(raws, "v2\n" , 3);
		} else {
			Posix.close(raws);
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
}
