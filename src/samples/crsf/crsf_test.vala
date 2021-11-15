// machine states

private const uint8 crc8_dvb_s2_tab[] = {
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

const uint8 BROADCAST_ADDRESS = 0x00;
const uint8 RADIO_ADDRESS = 0xea;
const uint8 GPS_ID = 0x02;
const uint8 VARIO_ID = 0x07;
const uint8 BAT_ID = 0x08;
const uint8 LINKSTATS_ID = 0x14;
const uint8 ATTI_ID = 0x1E;
const uint8 FM_ID = 0x21;
const uint8 DEV_ID = 0x29;

const uint8 TELEMETRY_RX_PACKET_SIZE = 128;
const double ATTITODEG = (57.29578 / 10000.0);

static uint8 crsf_buffer[128];
static uint8 crsf_index = 0;

const string[] sRFMode = {"4fps","50fps","150hz"};
const uint16[] sUpTXPwr = {0, 10, 25, 100, 500, 1000, 2000};

bool check_crsf_protocol (uint8 c) {
	return (c == 0xea) ? true : false;
}

bool crsf_decode(uint8 c)
{

  if (crsf_index == 0 && c != RADIO_ADDRESS) {
	  return false;
  }

  if (crsf_index == 1 && (c < 2 || c > TELEMETRY_RX_PACKET_SIZE-2)) {
	  crsf_index = 0;
	  return false;
  }

  if (crsf_index < TELEMETRY_RX_PACKET_SIZE) {
	  crsf_buffer[crsf_index] = c;
	  crsf_index++;
  }
  else {
	  crsf_index = 0;
	  return false;
  }

  if (crsf_index > 4) {
	  uint8 len = crsf_buffer[1];
    if (len + 2 == crsf_index) {
		process_crsf();
		crsf_index = 0;
    }
  }
  return true;
}

uint8 crc8_dvb_s2(uint8 crc, uint8 a)
{
	return crc8_dvb_s2_tab[crc ^ a];
}

bool check_crsf_crc()
{
	uint8 len = crsf_buffer[1];
	uint8 crc = 0;
	for(var k = 2; k <= len; k++) {
		crc = crc8_dvb_s2(crc, crsf_buffer[k]);
	}
	return (crc == crsf_buffer[len+1]);
}

private uint8 * deserialise_u32(uint8* rp, out uint32 v)
{
	v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
	return rp + sizeof(uint32);
}

private uint8 * deserialise_be_u24(uint8* rp, out uint32 v)
{
	v = (*(rp) << 16 |  (*(rp+1) << 8) | *(rp+2));
	return rp + 3*sizeof(uint8);
}

private uint8 * deserialise_u16(uint8* rp, out uint16 v)
{
	v = *rp | (*(rp+1) << 8);
	return rp + sizeof(uint16);
}

void process_crsf()
{
	if (!check_crsf_crc()) {
		stderr.printf("CRC Fails!\n");
		return;
  }

  uint8 id = crsf_buffer[2];
  uint8 *ptr = &crsf_buffer[3];
  uint32 val32;
  uint16 val16;

  switch(id) {
    case GPS_ID:
		ptr= deserialise_u32(ptr, out val32);  // Latitude (deg * 1e7)
		double lat = ((int32)Posix.ntohl(val32)) / 1e7;
		ptr= deserialise_u32(ptr, out val32); // Longitude (deg * 1e7)
		double lon = ((int32)Posix.ntohl(val32)) / 1e7;
		ptr= deserialise_u16(ptr, out val16); // Groundspeed ( km/h * 10 )
		double gspeed = 0;
		if (val16 != 0xffff) {
			gspeed = Posix.ntohs(val16) / 36.0; // m/s
		}
		ptr= deserialise_u16(ptr, out val16);  // COG Heading ( degree * 100 )
		double hdg = 0;
		if (val16 != 0xffff) {
			hdg = Posix.ntohs(val16) / 100.0; // deg
		}
		ptr= deserialise_u16(ptr, out val16);
		int32 alt= (int32)Posix.ntohs(val16) - 1000; // m
		uint8 nsat = *ptr;
		stdout.printf("GPS: %.6f %.6f %d m %.1f deg %.1f m/s %d sats\n", lat, lon, alt, hdg,
					  gspeed, nsat);
		break;
      case BAT_ID:
		  ptr= deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
		  double volts = 0;
		  if (val16 != 0xffff) {
			  volts = Posix.ntohs(val16) / 10.0; // Volts
		  }
		  ptr= deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
		  double amps = 0;
		  if (val16 != 0xffff) {
			  amps = Posix.ntohs(val16) / 10.0; // Amps
		  }
		  ptr = deserialise_be_u24(ptr, out val32);
		  uint32 capa = val32;
		  uint8 pctrem = *ptr;
		  stdout.printf("BAT: %.1fV, %.1fA  Draw: %u mAh Remain %d\n", volts, amps, capa, pctrem);
		break;

  case VARIO_ID:
	  ptr= deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
	  stdout.printf("VARIO: %d cm/s\n", (int16)val16);
	  break;
  case ATTI_ID:
	  ptr= deserialise_u16(ptr, out val16);  // Pitch radians *10000
	  double pitch = 0;
	  pitch = ((int16)Posix.ntohs(val16)) * ATTITODEG;
	  ptr= deserialise_u16(ptr, out val16);  // Roll radians *10000
	  double roll = 0;
	  roll = ((int16)Posix.ntohs(val16)) * ATTITODEG;
	  ptr= deserialise_u16(ptr, out val16);  // Roll radians *10000
	  double yaw = 0;
	  yaw = ((int16)Posix.ntohs(val16)) * ATTITODEG;
	  stdout.printf("ATTI: Pitch %.1f, Roll %.1f, Yaw %.1f\n", pitch, roll, yaw);
	  break;
  case FM_ID:
	  stdout.printf("FM: %s\n", (string)ptr );
	  break;
  case DEV_ID:
	  stdout.printf("DEV: %s\n", (string)(ptr+5));
	  break;
  case LINKSTATS_ID:
	  uint8 rssi1 = ptr[0];
	  uint8 rssi2 = ptr[1];
	  uint8 uplq = ptr[2];
	  int8 upsnr = (int8)ptr[3];
	  uint8 actant = ptr[4];
	  uint8 rfmode = ptr[5];
	  uint8 uptxpwr = ptr[6];
	  uint8 downrssi = ptr[7];
	  uint8 downlq = ptr[8];
	  int8 downsnr = (int8)ptr[9];

	  string smode = "??";
	  if (rfmode < sRFMode.length)
		  smode = sRFMode[rfmode];

	  string spwr = "??";
	  if (uptxpwr < sUpTXPwr.length)
		  spwr = "%dmW".printf(sUpTXPwr[uptxpwr]);
	  stdout.printf("LINK: RSSI1 %d RSSI2 %d UpLQ %d UpSNR %d ActAnt %d Mode %s TXPwr %s DnRSSI %d DnLQ %d DnSNR %d\n", rssi1, rssi2, uplq, upsnr, actant, smode, spwr, downrssi, downlq, downsnr);
	  break;
  default:
	  stdout.printf("UNK: Type %x %d\n", id, id);
	  break;
  }
}

static int main(string?[] args) {
	var fp = FileStream.open(args[1], "r");
	if(fp != null)
	{
		int c;
		bool is_crsf = false;
		while((c = fp.getc()) != -1) {
			if (!is_crsf)
				is_crsf = check_crsf_protocol((uint8)c);

			if(is_crsf)
				is_crsf = crsf_decode((uint8)c);
		}
	}
	return 0;
}
