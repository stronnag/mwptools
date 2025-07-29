enum State {
    Addr,
    Len,
    Func,
    Data,
    Crc,
}

const RADIO_ADDRESS: u8 = 0xea;
const TELEMETRY_RX_PACKET_SIZE: u8 = 128;

const ATTITODEG: f32 = 57.29578 / 10000.0;

const GPS_ID: u8 = 0x02;
const VARIO_ID: u8 = 0x07;
const BAT_ID: u8 = 0x08;
const LINKSTATS_ID: u8 = 0x14;
const ATTI_ID: u8 = 0x1E;
const FM_ID: u8 = 0x21;
const DEV_ID: u8 = 0x29;
const RADIO_ID: u8 = 0x3a;
const ARDUPILOT_RESP: u8 = 0x80;

const SRFMODE0: &[u16] = &[4, 50, 150];
const SRFMODE2: &[u16] = &[4, 25, 50, 100, 150, 200, 250, 500, 1000];
const SRFMODE3: &[u16] = &[4, 25, 50, 100, 150, 200, 250, 333, 500, 250, 500, 500, 1000];

const SUPTXPWR: &[u16] = &[10, 25, 50, 100, 250, 500, 1000, 2000];

pub struct CRSFReader {
    len: u8,
    count: u8,
    crc: u8,
    state: State,
    func: u8,
    payload: Vec<u8>,
    rftype: u8,
}

fn crc8_dvb_s2(c: u8, a: u8) -> u8 {
    let mut crc = c;
    crc ^= a;
    for _i in 0..8 {
        if (crc & 0x80) != 0 {
            crc = (crc << 1) ^ 0xd5;
        } else {
            crc <<= 1;
        }
    }
    crc
}

fn str_from_u8_nul_utf8(utf8_src: &[u8]) -> &str {
    let nul_range_end = utf8_src.iter()
        .position(|&c| c == b'\0')
        .unwrap_or(utf8_src.len()); // default to length if no `\0` present
    return ::std::str::from_utf8(&utf8_src[0..nul_range_end]).expect("Utf8 string")
}

impl CRSFReader {
    pub fn init(&mut self) {
        self.len = 0;
        self.count = 0;
        self.crc = 0;
        self.func = 0;
        self.state = State::Addr;
        self.payload.clear();
    }

    pub fn new(rftype: u8) -> CRSFReader {
        CRSFReader {
            len: 0,
            count: 0,
            crc: 0,
            state: State::Addr,
            func: 0,
            payload: Vec::new(),
            rftype,
        }
    }

    pub fn parse(&mut self, data: Vec<u8>, offset: Option<f64>) {
        for e in data.iter() {
            match self.state {
                State::Addr => {
                    if *e == RADIO_ADDRESS {
                        self.init();
                        self.state = State::Len;
                    } else {
                        //			eprintln!("Invalid start {}", *e);
                    }
                }
                State::Len => {
                    if *e > 2 && *e < TELEMETRY_RX_PACKET_SIZE - 2 {
                        self.state = State::Func;
                        self.len = *e - 2; // exclude type and crc (i.e. payload only)
                    } else {
                        //			eprintln!("Invalid packet size {}", *e);
                        self.init();
                    }
                }
                State::Func => {
                    self.state = State::Data;
                    self.func = *e;
                    self.crc = crc8_dvb_s2(0, *e);
                }
                State::Data => {
                    self.payload.push(*e);
                    self.crc = crc8_dvb_s2(self.crc, *e);
                    self.count += 1;
                    if self.count == self.len {
                        self.state = State::Crc;
                    }
                }

                State::Crc => {
                    let str: String;
                    if *e == self.crc {
                        str = self.describe();
                        if let Some(x) = offset {
                            print!("{:7.2}s: ", x);
                        }
                        println!("{}", str);
                    } else {
                        str = format!(
                            "CRC fail type={} len={} calc-crc={} msg-crc={} framelength={}",
                            self.func,
                            self.len,
                            self.crc,
                            *e,
                            data.len()
                        );
                        if let Some(x) = offset {
                            eprint!("{:7.2}s: ", x);
                        }
                        eprintln!("{}", str);
                    }
                    self.init();
                }
            }
        }
    }
    fn describe(&mut self) -> String {
        match self.func {
            GPS_ID => {
		if self.payload.len() == 15 {
                    let lat = i32::from_be_bytes(self.payload[0..4].try_into().unwrap()) as f32 / 1e7;
                    let lon = i32::from_be_bytes(self.payload[4..8].try_into().unwrap()) as f32 / 1e7;
                    let mut v16 = u16::from_be_bytes(self.payload[8..10].try_into().unwrap());
                    let mut gspeed: f32 = 0.0;
                    if v16 != 0xffff {
			gspeed = v16 as f32 / 36.0;
                    }
                    v16 = u16::from_be_bytes(self.payload[10..12].try_into().unwrap());
                    let mut hdr: f32 = 0.0;
                    if v16 != 0xffff {
			hdr = v16 as f32 / 100.0;
                    }
                    let alt: i32 =
			i16::from_be_bytes(self.payload[12..14].try_into().unwrap()) as i32 - 1000;
                    format!(
			"GPS: {:.6} {:.6} {}m {:.1}m/s {:.1}° {} sats",
			lat, lon, alt, gspeed, hdr, self.payload[14]
                    )
		} else {
		    "GPS decode error".to_string()
		}
            }
            VARIO_ID => {
		if self.payload.len() == 2 {
                    let vario = i16::from_be_bytes(self.payload[0..2].try_into().unwrap());
                    format!("VARIO {} cm/s", vario)
		} else {
		    "VARIO decode error".to_string()
		}
            }
            BAT_ID => {
		if  self.payload.len() > 6 {
                    let mut v16 = u16::from_be_bytes(self.payload[0..2].try_into().unwrap());
                    let mut volts: f32 = 0.0;
                    if v16 != 0xffff {
			volts = v16 as f32 / 10.0;
                    }
                    v16 = u16::from_be_bytes(self.payload[2..4].try_into().unwrap());
                    let mut amps: f32 = 0.0;
                    if v16 != 0xffff {
			amps = v16 as f32 / 10.0;
                    }
                    let capa: u32 = u32::from(self.payload[4]) << 16
			| u32::from(self.payload[5]) << 8
			| u32::from(self.payload[6]);

                    let mut pct = "".to_string();
                    if self.payload.len() > 7 {
			pct = format!(" {}%", self.payload[7])
                    }
                    format!("BAT: {:.2}V {:.2}A {}mah{}", volts, amps, capa, pct)
		} else {
		    "BAT_ID decode error".to_string()
		}
	    }

            LINKSTATS_ID => {
		if self.payload.len() == 10 {
                    let mut smode = "??".to_string();
                    let rfidx: usize = usize::from(self.payload[5]);
                    if self.rftype < 2 && rfidx >= SRFMODE0.len() && rfidx < SRFMODE2.len() {
			self.rftype = 2;
                    }

                    if self.rftype < 3 && rfidx >= SRFMODE2.len() && rfidx < SRFMODE3.len() {
			self.rftype = 3;
                    }

                    match self.rftype {
			2 => {
                            if rfidx < SRFMODE2.len() {
				smode = format!("{}", SRFMODE2[rfidx]);
                            }
			}
			3 => {
                            if rfidx < SRFMODE3.len() {
				smode = format!("{}", SRFMODE3[rfidx]);
                            }
			}
			_ => {
                            if rfidx < SRFMODE0.len() {
				smode = format!("{}", SRFMODE0[rfidx]);
                            }
			}
                    }
                    let mut txpwr = "??".to_string();
                    if u32::from(self.payload[6]) < SUPTXPWR.len().try_into().unwrap() {
			txpwr = format!("{}mW", SUPTXPWR[self.payload[6] as usize]);
                    }
                    format!(
			"LINKSTATS: rssi1 {} rssi2 {} UpLQ {} UpSNR {} ActAnt {} RFMode {}Hz TXPwr {} DnRSSI {} DnLQ {} DnSNR {}",
			self.payload[0],
			self.payload[1],
			self.payload[2],
			self.payload[3] as i8,
			self.payload[4],
			smode,
			txpwr,
			self.payload[7],
			self.payload[8],
			self.payload[9] as i8
                    )
		} else {
		    "LINKSTAT_ID decode error".to_string()
		}
            }
            ATTI_ID => {
		if self.payload.len() > 5 {
                    let pitch: f32 =
			(i16::from_be_bytes(self.payload[0..2].try_into().unwrap()) as f32 * ATTITODEG)
                        % 180.0;
                    let roll: f32 = (i16::from_be_bytes(self.payload[2..4].try_into().unwrap()) as f32
				     * ATTITODEG)
			% 180.0;
                    let yaw: f32 = (i16::from_be_bytes(self.payload[4..6].try_into().unwrap()) as f32
                    * ATTITODEG
                    + 180.0)
                    % 360.0;
                    format!("ATTI: p {:.2} r {:.2} y {:.2}", pitch, roll, yaw)
		} else {
		    "ATTI failed to decide".to_string()
		}
            }
            FM_ID => {
                format!(
                    "FM: {}", str_from_u8_nul_utf8(&self.payload[..self.payload.len() - 1])
                )
            }
            DEV_ID => {
                format!("DEV: {}", String::from_utf8_lossy(&self.payload[5..]))
            }
            RADIO_ID => {
		if self.payload.len() > 10 {
                if self.payload[0] == RADIO_ADDRESS && self.payload[2] == 0x10 {
                    let update: u32 =
                        u32::from_be_bytes(self.payload[3..7].try_into().unwrap()) / 10;
                    let offset: i32 =
                        i32::from_be_bytes(self.payload[7..11].try_into().unwrap()) / 10;
                    format!("RADIO: rate {}us offset {}us", update, offset)
                } else {
                    "RADIO: failed to decode".to_string()
                }
		} else {
                    "RADIO: failed to decode".to_string()
		}
            }
            ARDUPILOT_RESP => {
                format!("ARDUPILOT_RESP: {} bytes", self.len)
            }
            _ => format!(
                "UNKNOWN: Type {} 0x{:x}, payload len {}",
                self.func, self.func, self.len
            ),
        }
    }
}
