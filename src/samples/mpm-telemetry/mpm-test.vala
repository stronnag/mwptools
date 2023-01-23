/*
 * If  EDGETX Issue #1104 is implemented, this expects 'M', 'P' signature
 * with second parameter
 * mpm-test file # no headers
 * mpm-test file Y # headers
 */

// See  https://github.com/pascallanger/DIY-Multiprotocol-TX-Module/blob/master/Multiprotocol/Multiprotocol.h

namespace SEDE {
	uint8 * deserialise_u32(uint8* rp, out uint32 v) {
        v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
        return rp + sizeof(uint32);
    }

    uint8 * deserialise_u16(uint8* rp, out uint16 v) {
        v = *rp | (*(rp+1) << 8);
        return rp + sizeof(uint16);
    }
}

namespace FRSKY {
    enum FrID {
        ALT_ID = 0x0100,
        VARIO_ID = 0x0110,
        CURR_ID = 0x0200,
        VFAS_ID = 0x0210,
        CELLS_ID = 0x0300,
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
        T1_ID = 0x0400,
        T2_ID = 0x0410,
		HOME_DIST  = 0x0420,
		PITCH      = 0x0430 ,
        ROLL       = 0x0440 ,
		COG = 0x0450,
		AZIMUTH = 0x0460,
    }

    bool fr_checksum(uint8[] buf) {
        uint16 crc = 0;
        foreach (var b in buf[2:10]) {
            crc += b;
            crc += crc >> 8;
            crc &= 0xff;
        }
        return (crc == 0xff);
    }

	bool frsky_decode(uint8 []buf) {
		bool res = fr_checksum(buf);
        if(res){
            ushort id;
            uint val;
            SEDE.deserialise_u16(buf+3, out id);
            SEDE.deserialise_u32(buf+5, out val);
			string s;
			s = ((FrID)id).to_string();
			if (s == null)
				s = "%04x".printf(id);

            stdout.printf("Sport: %s %u\n", s, val);
        } else {
            stdout.printf("Sport: Checksum error\n");
		}
        return res;
	}
}

namespace FLYSKY {
	struct Telem {
		int32 mask;
		int status;
		double vbat;
		double curr;
		int rssi;
		int heading;
		int alt;
		int homedirn;
		int homedist;
		int cog;
		int ilat;
		int ilon;
		int galt;
		double speed;
	}

	private const string[] modemap = {"Manual","Acro","Horizon","Angle","WP", "AH", "PH",
		"RTH", "Launch", "Failsafe"};

	enum Func {
		VBAT = 1,
		STATUS = 3,
		HEADING = 4,
		CURR = 5,
		ALT = 6,
		HOMEDIRN = 7,
		HOMEDIST = 8,
		COG = 9,
		GALT = 10,
		LAT1 = 11,
		LON1 = 12,
		LAT0 = 13,
		LON0 = 14,
		SPEED = 15,
	}

	private Telem telem;

	void show_telem() {
		int mode = telem.status % 10;
		int hdop = (telem.status % 100) / 10;
		int nsat = (telem.status / 1000);
		hdop = hdop*10 + 1;
		int fix = 0;
		bool home = false;
		int ifix = (telem.status % 1000) / 100;
		if (ifix > 4) {
			home = true;
			ifix =- 5;
		}
		fix = ifix & 3;
		stdout.printf("Status %d, Mode %s (%d) , nsat %d, fix %d, hdop %d, home %s\n",
					  telem.status, modemap[mode], mode, nsat, fix, hdop, home.to_string());
		stdout.printf("VBat: %.2f V\n", telem.vbat);
		stdout.printf("RSSI: %d %%\n", telem.rssi);
		stdout.printf("Alt: %d m\n", telem.alt);
		stdout.printf("HDirn: %d deg\n", telem.homedirn);
		stdout.printf("HDist: %d m\n", telem.homedist);
		stdout.printf("Cog: %d deg\n", telem.cog);
		stdout.printf("Hdr: %d deg\n", telem.heading);
		stdout.printf("lat: %f \n", (double)telem.ilat/1e7);
		stdout.printf("lon: %f \n", (double)telem.ilon/1e7);
		stdout.printf("galt: %d m\n", telem.galt);
		stdout.printf("speed: %.1f m/s\n", telem.speed);
		telem = {};
	}

	void decode(uint8[]buf, uint8 typ) {
		uint8 *bp = buf;
		uint16 val;
		telem.rssi = (*bp * 100) / 255;
		bp++;
		for(var s = 0; s < 7; s++) {
			uint8 sensid = bp[1];
			uint8 id = bp[0];
			bp = SEDE.deserialise_u16(bp+2, out val);
			stderr.printf("%d %d %d\n", id, sensid, val);
			switch (sensid) { // instance
			case 1:
				telem.vbat = val/100.0;
				break;
			case 3:
				telem.status = val;
				break;
			case 4:
				telem.heading = val / 100;
				break;
			case 5:
				telem.curr = val/100.0;
				break;
			case 6:
				telem.alt = val/100;
				break;
			case 7:
				telem.homedirn = val;
				break;
			case 8:
				telem.homedist = val;
				break;
			case 9:
				telem.cog = (int16)val;
				break;
			case 10:
				telem.galt = (int16)val;
				break;
			case 11:
				telem.ilat += 10*(int16)val;
				break;
			case 12:
				telem.ilon += 10*(int16)val;
				break;
			case 13:
				telem.ilat += 100000 * (int16)val;
				break;
			case 14:
				telem.ilon += 100000 * (int16)val;
				break;
			case 15:
				telem.speed = val/3.6;
				break;
			case 255:
				if (telem.mask != 0) {
					show_telem();
				}
				break;
			}
			if(sensid != 0xff)
				telem.mask |= (1 <<  sensid);
		}
	}
}

namespace MPM {
	enum State {
		L_M,
		L_P,
		L_TYPE,
		L_LEN,
		L_DATA,
		L_SKIP,
	}

	enum Mtype {
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

	static uint8 mpm_buf[128];
	static uint8 skip = 0;
	static Mtype type = 0;
	//                      0    1   2  3   4   5   6  7  8  9  a  b   c  d   e  f  10 11
	const uint8 []tlens = {0, 0x18, 9, 9, 16, 16, 29, 0, 4, 0, 8, 6, 29, 0, 14, 10, 22, 0};

	static State state;

	void  init_state(bool use_mp) {
		state = (use_mp) ? State.L_M : State.L_TYPE;
	}

	void decode(uint8 c, bool use_mp) {

		switch (state) {
		case State.L_M:
			if (c == 'M')
				state = State.L_P;
			break;
		case State.L_P:
			if (c == 'P')
				state = State.L_TYPE;
			else
				init_state(use_mp);
			break;

		case State.L_TYPE:
			if (c > 0 && c < Mtype.MPM_MAXTYPE && c != Mtype.MPM_UNUSED1 && c != Mtype.MPM_UNUSED2 )  {
				type = (Mtype)c;
				state = State.L_LEN;
			} else {
				init_state(use_mp);
			}
			break;
		case State.L_LEN:
			var tl  = tlens[type];
			if (tl != 0 && c == tl) {
				state = State.L_DATA;
				skip = tl;
			} else {
				init_state(use_mp);
			}
			break;

		case State.L_DATA:
			mpm_buf[tlens[type] - skip] = c;
			skip--;
			if (skip == 0) {
				switch(type) {
				case Mtype.MPM_FRSKY:
					stdout.printf("Got a FRSKY buffer\n");
					mpm_buf.move(0, 1, 10);
					mpm_buf[0] = 0x7e;
					FRSKY.frsky_decode(mpm_buf);
					break;
				case Mtype.MPM_FLYSKYAA:
					stdout.printf("Got a FLYSKY AA buffer\n");
					FLYSKY.decode(mpm_buf, 0xaa);
					break;
				case Mtype.MPM_FLYSKYAC:
					stdout.printf("Got a FLYSKY AC buffer\n");
					FLYSKY.decode(mpm_buf, 0xac);
					break;
				default:
					stdout.printf("Unknown %s\n", type.to_string());
					break;
				}
				init_state(use_mp);
			}
			break;
		case State.L_SKIP:
			skip--;
			if (skip == 0) {
				init_state(use_mp);
			}
			break;
		}
	}
}


static int main(string?[] args) {
	if (args.length > 1) {
		bool use_mp = (args.length > 2);
		var fp = FileStream.open(args[1], "r");
		if(fp != null) {
			int c;
			MPM.init_state(use_mp);
			while((c = fp.getc()) != -1) {
				MPM.decode((uint8)c, use_mp);
			}
		}
	}
	return 0;
}
