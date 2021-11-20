// See  https://github.com/pascallanger/DIY-Multiprotocol-TX-Module/blob/master/Multiprotocol/Multiprotocol.h

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

    bool fr_checksum(uint8[] buf)
    {
        uint16 crc = 0;
        foreach (var b in buf[2:10])
        {
            crc += b;
            crc += crc >> 8;
            crc &= 0xff;
        }
        return (crc == 0xff);
    }

	uint8 * deserialise_u32(uint8* rp, out uint32 v)
    {
        v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
        return rp + sizeof(uint32);
    }

    uint8 * deserialise_u16(uint8* rp, out uint16 v)
    {
        v = *rp | (*(rp+1) << 8);
        return rp + sizeof(uint16);
    }

	bool frsky_decode(uint8 []buf) {
		bool res = fr_checksum(buf);
        if(res)
        {
            ushort id;
            uint val;
            deserialise_u16(buf+3, out id);
            deserialise_u32(buf+5, out val);
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

namespace MPM {
	enum State {
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
		MPM_FLYSKY2 = 6,
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

	static uint8 frbuf[16];
	static uint8 skip = 0;
	static uint8 type = 0;
	//                      0    1   2  3   4   5   6  7  8  9  a  b   c  d   e  f  10 11
	const uint8 []tlens = {0, 0x18, 9, 9, 16, 16, 29, 0, 4, 0, 8, 6, 29, 0, 14, 10, 22, 0};

	static State state = State.L_TYPE;
	void decode(uint8 c) {
		switch (state) {
		case State.L_TYPE:
			if (c > 0 && c < Mtype.MPM_MAXTYPE && c != Mtype.MPM_UNUSED1 && c != Mtype.MPM_UNUSED2 )  {
				type = c;
				state = State.L_LEN;
			} else {
				state = State.L_TYPE;
			}
			break;
		case State.L_LEN:
			var tl  = tlens[type];
			if (tl != 0 && c == tl) {
				if (type == Mtype.MPM_FRSKY) {
					frbuf[0] = 0x7e; // legacy
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
			frbuf[tlens[Mtype.MPM_FRSKY] - skip + 1] = c;
			skip--;
			if (skip == 0) {
				stdout.printf("Got a FRSKY buffer\n");
				FRSKY.frsky_decode(frbuf);
				state = State.L_TYPE;
			}
			break;
		case State.L_SKIP:
			skip--;
			if (skip == 0) {
				state = State.L_TYPE;
			}
			break;
		}
	}
}

static int main(string?[] args) {
	var fp = FileStream.open(args[1], "r");
	if(fp != null)
	{
		int c;
		while((c = fp.getc()) != -1) {
			MPM.decode((uint8)c);
		}
	}
	return 0;
}
