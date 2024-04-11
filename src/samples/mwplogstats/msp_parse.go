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

	state_L_FRAME
	state_L_DATA
	state_L_CRC

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

var (
	count      = uint16(0)
	crc        = byte(0)
	pstate     = state_INIT
	sc         MsgData
	ltmmap     map[byte]uint16
	mspnamemap map[uint16]string
)

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

func mspinit() {
	ltmmap = map[byte]uint16{
		'A': 6,
		'G': 14,
		'N': 6,
		'O': 14,
		'S': 7,
		'X': 6,
	}

	mspnamemap = map[uint16]string{
		0:      "MSP_PROTOCOL_VERSION",
		1:      "MSP_API_VERSION",
		2:      "MSP_FC_VARIANT",
		3:      "MSP_FC_VERSION",
		4:      "MSP_BOARD_INFO",
		5:      "MSP_BUILD_INFO",
		6:      "MSP_INAV_PID",
		7:      "MSP_SET_INAV_PID",
		10:     "MSP_NAME",
		11:     "MSP_SET_NAME",
		12:     "MSP_NAV_POSHOLD",
		13:     "MSP_SET_NAV_POSHOLD",
		14:     "MSP_CALIBRATION_DATA",
		15:     "MSP_SET_CALIBRATION_DATA",
		16:     "MSP_POSITION_ESTIMATION_CONFIG",
		17:     "MSP_SET_POSITION_ESTIMATION_CONFIG",
		18:     "MSP_WP_MISSION_LOAD",
		19:     "MSP_WP_MISSION_SAVE",
		20:     "MSP_WP_GETINFO",
		21:     "MSP_RTH_AND_LAND_CONFIG",
		22:     "MSP_SET_RTH_AND_LAND_CONFIG",
		23:     "MSP_FW_CONFIG",
		24:     "MSP_SET_FW_CONFIG",
		34:     "MSP_MODE_RANGES",
		35:     "MSP_SET_MODE_RANGE",
		36:     "MSP_FEATURE",
		37:     "MSP_SET_FEATURE",
		38:     "MSP_BOARD_ALIGNMENT",
		39:     "MSP_SET_BOARD_ALIGNMENT",
		40:     "MSP_CURRENT_METER_CONFIG",
		41:     "MSP_SET_CURRENT_METER_CONFIG",
		42:     "MSP_MIXER",
		43:     "MSP_SET_MIXER",
		44:     "MSP_RX_CONFIG",
		45:     "MSP_SET_RX_CONFIG",
		46:     "MSP_LED_COLORS",
		47:     "MSP_SET_LED_COLORS",
		48:     "MSP_LED_STRIP_CONFIG",
		49:     "MSP_SET_LED_STRIP_CONFIG",
		50:     "MSP_RSSI_CONFIG",
		51:     "MSP_SET_RSSI_CONFIG",
		52:     "MSP_ADJUSTMENT_RANGES",
		53:     "MSP_SET_ADJUSTMENT_RANGE",
		54:     "MSP_CF_SERIAL_CONFIG",
		55:     "MSP_SET_CF_SERIAL_CONFIG",
		56:     "MSP_VOLTAGE_METER_CONFIG",
		57:     "MSP_SET_VOLTAGE_METER_CONFIG",
		58:     "MSP_SONAR_ALTITUDE",
		64:     "MSP_RX_MAP",
		65:     "MSP_SET_RX_MAP",
		68:     "MSP_REBOOT",
		70:     "MSP_DATAFLASH_SUMMARY",
		71:     "MSP_DATAFLASH_READ",
		72:     "MSP_DATAFLASH_ERASE",
		73:     "MSP_LOOP_TIME",
		74:     "MSP_SET_LOOP_TIME",
		75:     "MSP_FAILSAFE_CONFIG",
		76:     "MSP_SET_FAILSAFE_CONFIG",
		79:     "MSP_SDCARD_SUMMARY",
		80:     "MSP_BLACKBOX_CONFIG",
		81:     "MSP_SET_BLACKBOX_CONFIG",
		82:     "MSP_TRANSPONDER_CONFIG",
		83:     "MSP_SET_TRANSPONDER_CONFIG",
		84:     "MSP_OSD_CONFIG",
		85:     "MSP_SET_OSD_CONFIG",
		86:     "MSP_OSD_CHAR_READ",
		87:     "MSP_OSD_CHAR_WRITE",
		88:     "MSP_VTX_CONFIG",
		89:     "MSP_SET_VTX_CONFIG",
		90:     "MSP_ADVANCED_CONFIG",
		91:     "MSP_SET_ADVANCED_CONFIG",
		92:     "MSP_FILTER_CONFIG",
		93:     "MSP_SET_FILTER_CONFIG",
		94:     "MSP_PID_ADVANCED",
		95:     "MSP_SET_PID_ADVANCED",
		96:     "MSP_SENSOR_CONFIG",
		97:     "MSP_SET_SENSOR_CONFIG",
		98:     "MSP_SPECIAL_PARAMETERS",
		99:     "MSP_SET_SPECIAL_PARAMETERS",
		100:    "MSP_IDENT",
		137:    "MSP_VTXTABLE_BAND",
		138:    "MSP_VTXTABLE_POWERLEVEL",
		180:    "MSP_OSD_VIDEO_CONFIG",
		181:    "MSP_SET_OSD_VIDEO_CONFIG",
		182:    "MSP_DISPLAYPORT",
		186:    "MSP_SET_TX_INFO",
		187:    "MSP_TX_INFO",
		101:    "MSP_STATUS",
		102:    "MSP_RAW_IMU",
		103:    "MSP_SERVO",
		104:    "MSP_MOTOR",
		105:    "MSP_RC",
		106:    "MSP_RAW_GPS",
		107:    "MSP_COMP_GPS",
		108:    "MSP_ATTITUDE",
		109:    "MSP_ALTITUDE",
		110:    "MSP_ANALOG",
		111:    "MSP_RC_TUNING",
		113:    "MSP_ACTIVEBOXES",
		114:    "MSP_MISC",
		116:    "MSP_BOXNAMES",
		117:    "MSP_PIDNAMES",
		118:    "MSP_WP",
		119:    "MSP_BOXIDS",
		120:    "MSP_SERVO_CONFIGURATIONS",
		121:    "MSP_NAV_STATUS",
		122:    "MSP_NAV_CONFIG",
		124:    "MSP_3D",
		125:    "MSP_RC_DEADBAND",
		126:    "MSP_SENSOR_ALIGNMENT",
		127:    "MSP_LED_STRIP_MODECOLOR",
		130:    "MSP_BATTERY_STATE",
		200:    "MSP_SET_RAW_RC",
		201:    "MSP_SET_RAW_GPS",
		203:    "MSP_SET_BOX",
		204:    "MSP_SET_RC_TUNING",
		205:    "MSP_ACC_CALIBRATION",
		206:    "MSP_MAG_CALIBRATION",
		207:    "MSP_SET_MISC",
		208:    "MSP_RESET_CONF",
		209:    "MSP_SET_WP",
		210:    "MSP_SELECT_SETTING",
		211:    "MSP_SET_HEAD",
		212:    "MSP_SET_SERVO_CONFIGURATION",
		214:    "MSP_SET_MOTOR",
		215:    "MSP_SET_NAV_CONFIG",
		217:    "MSP_SET_3D",
		218:    "MSP_SET_RC_DEADBAND",
		219:    "MSP_SET_RESET_CURR_PID",
		220:    "MSP_SET_SENSOR_ALIGNMENT",
		221:    "MSP_SET_LED_STRIP_MODECOLOR",
		250:    "MSP_EEPROM_WRITE",
		251:    "MSP_RESERVE_1",
		252:    "MSP_RESERVE_2",
		253:    "MSP_DEBUGMSG",
		254:    "MSP_DEBUG",
		255:    "MSP_V2_FRAME",
		150:    "MSP_STATUS_EX",
		151:    "MSP_SENSOR_STATUS",
		160:    "MSP_UID",
		164:    "MSP_GPSSVINFO",
		166:    "MSP_GPSSTATISTICS",
		240:    "MSP_ACC_TRIM",
		239:    "MSP_SET_ACC_TRIM",
		241:    "MSP_SERVO_MIX_RULES",
		242:    "MSP_SET_SERVO_MIX_RULE",
		245:    "MSP_SET_PASSTHROUGH",
		246:    "MSP_RTC",
		247:    "MSP_SET_RTC",
		0x1001: "MSP2_COMMON_TZ",
		0x1002: "MSP2_COMMON_SET_TZ",
		0x1003: "MSP2_COMMON_SETTING",
		0x1004: "MSP2_COMMON_SET_SETTING",
		0x1005: "MSP2_COMMON_MOTOR_MIXER",
		0x1006: "MSP2_COMMON_SET_MOTOR_MIXER",
		0x1007: "MSP2_COMMON_SETTING_INFO",
		0x1008: "MSP2_COMMON_PG_LIST",
		0x1009: "MSP2_COMMON_SERIAL_CONFIG",
		0x100A: "MSP2_COMMON_SET_SERIAL_CONFIG",
		0x100B: "MSP2_COMMON_SET_RADAR_POS",
		0x100C: "MSP2_COMMON_SET_RADAR_ITD",
		0x2000: "MSP2_INAV_STATUS",
		0x2001: "MSP2_INAV_OPTICAL_FLOW",
		0x2002: "MSP2_INAV_ANALOG",
		0x2003: "MSP2_INAV_MISC",
		0x2004: "MSP2_INAV_SET_MISC",
		0x2005: "MSP2_INAV_BATTERY_CONFIG",
		0x2006: "MSP2_INAV_SET_BATTERY_CONFIG",
		0x2007: "MSP2_INAV_RATE_PROFILE",
		0x2008: "MSP2_INAV_SET_RATE_PROFILE",
		0x2009: "MSP2_INAV_AIR_SPEED",
		0x200A: "MSP2_INAV_OUTPUT_MAPPING",
		0x200B: "MSP2_INAV_MC_BRAKING",
		0x200C: "MSP2_INAV_SET_MC_BRAKING",
		0x200D: "MSP2_INAV_OUTPUT_MAPPING_EXT",
		0x200E: "MSP2_INAV_TIMER_OUTPUT_MODE",
		0x200F: "MSP2_INAV_SET_TIMER_OUTPUT_MODE",
		0x2010: "MSP2_INAV_MIXER",
		0x2011: "MSP2_INAV_SET_MIXER",
		0x2012: "MSP2_INAV_OSD_LAYOUTS",
		0x2013: "MSP2_INAV_OSD_SET_LAYOUT_ITEM",
		0x2014: "MSP2_INAV_OSD_ALARMS",
		0x2015: "MSP2_INAV_OSD_SET_ALARMS",
		0x2016: "MSP2_INAV_OSD_PREFERENCES",
		0x2017: "MSP2_INAV_OSD_SET_PREFERENCES",
		0x2018: "MSP2_INAV_SELECT_BATTERY_PROFILE",
		0x2019: "MSP2_INAV_DEBUG",
		0x201A: "MSP2_BLACKBOX_CONFIG",
		0x201B: "MSP2_SET_BLACKBOX_CONFIG",
		0x201C: "MSP2_INAV_TEMP_SENSOR_CONFIG",
		0x201D: "MSP2_INAV_SET_TEMP_SENSOR_CONFIG",
		0x201E: "MSP2_INAV_TEMPERATURES",
		0x201F: "MSP_SIMULATOR",
		0x2020: "MSP2_INAV_SERVO_MIXER",
		0x2021: "MSP2_INAV_SET_SERVO_MIXER",
		0x2022: "MSP2_INAV_LOGIC_CONDITIONS",
		0x2023: "MSP2_INAV_SET_LOGIC_CONDITIONS",
		0x2024: "MSP2_INAV_GLOBAL_FUNCTIONS",
		0x2025: "MSP2_INAV_SET_GLOBAL_FUNCTIONS",
		0x2026: "MSP2_INAV_LOGIC_CONDITIONS_STATUS",
		0x2027: "MSP2_INAV_GVAR_STATUS",
		0x2028: "MSP2_INAV_PROGRAMMING_PID",
		0x2029: "MSP2_INAV_SET_PROGRAMMING_PID",
		0x202A: "MSP2_INAV_PROGRAMMING_PID_STATUS",
		0x2030: "MSP2_PID",
		0x2031: "MSP2_SET_PID",
		0x2032: "MSP2_INAV_OPFLOW_CALIBRATION",
		0x2033: "MSP2_INAV_FWUPDT_PREPARE",
		0x2034: "MSP2_INAV_FWUPDT_STORE",
		0x2035: "MSP2_INAV_FWUPDT_EXEC",
		0x2036: "MSP2_INAV_FWUPDT_ROLLBACK_PREPARE",
		0x2037: "MSP2_INAV_FWUPDT_ROLLBACK_EXEC",
		0x2038: "MSP2_INAV_SAFEHOME",
		0x2039: "MSP2_INAV_SET_SAFEHOME",
		0x203A: "MSP2_INAV_MISC2",
		0x203B: "MSP2_INAV_LOGIC_CONDITIONS_SINGLE",
		0x2040: "MSP2_INAV_ESC_RPM",
		0x2048: "MSP2_INAV_LED_STRIP_CONFIG_EX",
		0x2049: "MSP2_INAV_SET_LED_STRIP_CONFIG_EX",
		0x204A: "MSP2_INAV_FW_APPROACH",
		0x204B: "MSP2_INAV_SET_FW_APPROACH",
		0x2060: "MSP2_INAV_RATE_DYNAMICS",
		0x2061: "MSP2_INAV_SET_RATE_DYNAMICS",
		0x2070: "MSP2_INAV_EZ_TUNE",
		0x2071: "MSP2_INAV_EZ_TUNE_SET",
		0x2080: "MSP2_INAV_SELECT_MIXER_PROFILE",
		0x2090: "MSP2_ADSB_VEHICLE_LIST",
		0x2100: "MSP2_INAV_CUSTOM_OSD_ELEMENTS",
		0x2101: "MSP2_INAV_SET_CUSTOM_OSD_ELEMENTS",
		0x1F01: "MSP2_SENSOR_RANGEFINDER",
		0x1F02: "MSP2_SENSOR_OPTIC_FLOW",
		0x1F03: "MSP2_SENSOR_GPS",
		0x1F04: "MSP2_SENSOR_COMPASS",
		0x1F05: "MSP2_SENSOR_BAROMETER",
		0x1F06: "MSP2_SENSOR_AIRSPEED",
	}
}

func msp_output(mspfh io.WriteCloser, sc MsgData) {
	if sc.vers == 'L' {
		fmt.Fprintf(mspfh, "LTM '%c' frame, paylen=%d %s", sc.cmd, sc.len, HexArray(sc.data[:sc.len]))
	} else {
		var mspname string
		mspname, ok := mspnamemap[sc.cmd]
		if !ok {
			mspname = "{unknown}"
		}
		fmt.Fprintf(mspfh, "MSP%d %c %s (%d,0x%x) paylen=%d", sc.vers, sc.dirn, mspname, sc.cmd, sc.cmd, sc.len)
		if sc.cmd == msp2_COMMON_SETTING && sc.dirn == '<' {
			fmt.Fprintf(mspfh, " %s", string(sc.data[:sc.len-1]))
		} else if sc.dirn == '>' && (sc.cmd == msp_NAME || sc.cmd == msp_BOXNAMES) {
			fmt.Fprintf(mspfh, " %s", string(sc.data[:sc.len]))
		} else if sc.len > 0 {
			fmt.Fprintf(mspfh, " %s", HexArray(sc.data[:sc.len]))
		}
	}
	fmt.Fprintln(mspfh)
}

func ts_output(mspfh io.WriteCloser, offset float64) {
	fmt.Fprintf(mspfh, "%8.3f ", offset)
}

func msp_parse(mspfh io.WriteCloser, inp []byte, offset float64) {
	for i, _ := range inp {
		switch pstate {
		case state_INIT:
			if inp[i] == '$' {
				pstate = state_M
				sc.ok = false
				sc.len = 0
				sc.cmd = 0
			}
		case state_M:
			if inp[i] == 'M' {
				sc.vers = 1
				pstate = state_DIRN
			} else if inp[i] == 'X' {
				sc.vers = 2
				pstate = state_X_HEADER2
			} else if inp[i] == 'T' {
				sc.vers = 'L'
				pstate = state_L_FRAME
			} else {
				pstate = state_INIT
			}

		case state_L_FRAME:
			ln, ok := ltmmap[inp[i]]
			sc.len = ln
			sc.cmd = uint16(inp[i])
			if ok {
				pstate = state_L_DATA
				count = 0
				crc = 0
				sc.data = make([]byte, sc.len)
			} else {
				pstate = state_INIT
			}

		case state_DIRN:
			sc.dirn = inp[i]
			if inp[i] == '!' {
				pstate = state_LEN
			} else if inp[i] == '<' || inp[i] == '>' {
				pstate = state_LEN
				sc.ok = true
			} else {
				pstate = state_INIT
			}

		case state_X_HEADER2:
			sc.dirn = inp[i]
			if inp[i] == '!' {
				pstate = state_X_FLAGS
			} else if inp[i] == '>' || inp[i] == '<' {
				pstate = state_X_FLAGS
				sc.ok = true
			} else {
				pstate = state_INIT
			}
		case state_X_FLAGS:
			crc = crc8_dvb_s2(0, inp[i])
			pstate = state_X_ID1

		case state_X_ID1:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.cmd = uint16(inp[i])
			pstate = state_X_ID2

		case state_X_ID2:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.cmd |= (uint16(inp[i]) << 8)
			pstate = state_X_LEN1

		case state_X_LEN1:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.len = uint16(inp[i])
			pstate = state_X_LEN2

		case state_X_LEN2:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.len |= (uint16(inp[i]) << 8)
			if sc.len > 0 {
				pstate = state_X_DATA
				count = 0
				sc.data = make([]byte, sc.len)
			} else {
				pstate = state_X_CHECKSUM
			}
		case state_X_DATA:
			crc = crc8_dvb_s2(crc, inp[i])
			sc.data[count] = inp[i]
			count++
			if count == sc.len {
				pstate = state_X_CHECKSUM
			}
		case state_X_CHECKSUM:
			ccrc := inp[i]
			ts_output(mspfh, offset)
			if crc != ccrc {
				fmt.Fprintf(mspfh, "CRC error on %d\n", sc.cmd)
			} else {
				msp_output(mspfh, sc)
			}
			pstate = state_INIT

		case state_LEN:
			sc.len = uint16(inp[i])
			crc = inp[i]
			pstate = state_CMD
		case state_CMD:
			sc.cmd = uint16(inp[i])
			crc ^= inp[i]
			if sc.len == 0 {
				pstate = state_CRC
			} else {
				sc.data = make([]byte, sc.len)
				pstate = state_DATA
				count = 0
			}

		case state_DATA:
			sc.data[count] = inp[i]
			crc ^= inp[i]
			count++
			if count == sc.len {
				pstate = state_CRC
			}

		case state_CRC:
			ccrc := inp[i]
			ts_output(mspfh, offset)
			if crc != ccrc {
				fmt.Fprintf(mspfh, "CRC error on %d\n", sc.cmd)
			} else {
				msp_output(mspfh, sc)
			}
			pstate = state_INIT

		case state_L_DATA:
			sc.data[count] = inp[i]
			crc ^= inp[i]
			count++
			if count == sc.len {
				pstate = state_L_CRC
			}

		case state_L_CRC:
			ccrc := inp[i]
			ts_output(mspfh, offset)
			if crc != ccrc {
				fmt.Fprintf(mspfh, "CRC error on %d\n", sc.cmd)
			} else {
				msp_output(mspfh, sc)
			}
			pstate = state_INIT
		}
	}
}
