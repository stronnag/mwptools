/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

namespace Mwp {
    const string[] failnames = {"WPNO","ACT","LAT","LON","ALT","P1","P2","P3","FLAG"};
	const uint32 ADSB_DISTNDEF = (uint32)0xffffffff;

	/* There is a single timer that monitors message state
	   This runs at 100ms (TIMINTVL). Other monitoring times are defined in terms of this
	   timer.
	   Two other monitoring intervals are defined by configuration.
	   poll-timeout : messging poll timeout (default 900ms)
	   gpsintvl     : gps-data timeout (default 150ms)
	 */

	const uint TIMINTVL     = 100;              // 100 milliseconds
	const uint STATINTVL    = ( 1000/TIMINTVL); //  1 sec, status update
	const uint MAVINTVL     = ( 2000/TIMINTVL); //  2 sec, push telemetry t/o
	const uint USATINTVL    = ( 2000/TIMINTVL); //  2 sec, change in sats message
	const uint CRITINTVL    = ( 3000/TIMINTVL); //  3 sec, GPS critical message
	const uint UUSATINTVL   = ( 4000/TIMINTVL); //  4 sec, change in sats message
	const uint NODATAINTVL  = ( 5000/TIMINTVL); //  5 sec, no data warning
	const uint SATINTVL     = (10000/TIMINTVL); // 10 sec, sats change
	const uint RESTARTINTVL = (30000/TIMINTVL); // 30 sec, poller inactivity

	const uint MAXMULTI = 9;
    const uint NVARIO=2;
    const double RAD2DEG = 57.29578;

	const uint8 MAV_BEAT_MASK=7; // mask, some power of 2 - 1
    private const uint MAXVSAMPLE=12;

	public enum FCVERS {
        hasMoreWP =   0x010400,
        hasEEPROM =   0x010600,
        hasTZ =       0x010704,
        hasRCDATA =   0x010800,
        hasV2STATUS = 0x010801,
        hasJUMP =     0x020500,
        hasPOI =      0x020600,
        hasPHTIME =   0x020500,
        hasLAND =     0x020500,
        hasSAFEAPI =  0x020700,
        hasMONORTH =  0x020600,
        hasABSALT =   0x030000,
        hasWP_V4 =    0x040000,
        hasWP1m =     0x060000,
		hasFWApp =    0x070100,
		hasActiveWP = 0x070100,
		hasAdsbList = 0x070101,
		hasGeoZones = 0x080000,
    }

	public enum WPS {
        isINAV = (1<<0),
        isFW = (1<<1),
        hasJUMP = (1<<2),
        hasPHT = (1<<3),
        hasLAND = (1<<4),
        hasPOI = (1<<5),
    }

    public enum SERSTATE {
        NONE=0,
        NORMAL,
        POLLER,
		SET_WP,
		EXTRA_WP,
        TELEM = 128,
        TELEM_SP,
    }

    public enum DEBUG_FLAGS {
        NONE=0,
        WP = (1 << 0),          // 1
        INIT = (1 << 1),        // 2
        MSP = (1 << 2),			// 4
        ADHOC = (1 << 3),		// 8
        RADAR= (1 << 4),		// 16
        OTXSTDERR = (1 << 5),	// 32
		SERIAL = (1 << 6),		// 64
		VIDEO = (1 << 7),		// 128
		GCSLOC = (1 << 8),		// 256
		LOSANA = (1 << 9),		// 512
		RDRLIST = (1 << 10),	// 1024
    }

    private enum SAT_FLAGS {
        NONE=0,
        NEEDED = 1,
        URGENT = 2,
        BEEP = 4
    }

    private enum Player {
        NONE = 0,
        MWP = 1,
        BBOX = 2,
        OTX = 4,
        FL2LTM = 8,
        RAW = 16,
        FAST_MASK = 128,
        MWP_FAST = MWP |FAST_MASK,
        BBOX_FAST = BBOX|FAST_MASK,
        OTX_FAST = OTX|FAST_MASK,
        FL2_FAST = FL2LTM|FAST_MASK,
        RAW_FAST = RAW|FAST_MASK,
    }

	enum SPEAKER_API {
		NONE=0,
		ESPEAK=1,
		SPEECHD=2,
		FLITE=3,
		EXTERNAL=4,
		COUNT=5
	}

    private enum APIVERS {
        mspV2 = 0x0200,
        mixer = 0x0202,
    }

    private enum WPDL {
        IDLE=0,
        DOWNLOAD = (1<<0),
        REPLACE = (1<<1),
        POLL = (1<<2),
        REPLAY = (1<<3),
        SAVE_EEPROM = (1<<4),
        GETINFO = (1<<5),
        CALLBACK = (1<<6),
        CANCEL = (1<<7),
		SET_ACTIVE = (1<<8),
		SAVE_ACTIVE = (1<<9),
		RESET_POLLER = (1<<10),
		KICK_DL = (1<<11),
        FOLLOW_ME = (1 << 12),
		SAVE_FWA = (1 << 13),
    }

    private struct WPMGR {
        MSP_WP[] wps;
        WPDL wp_flag;
        uint8 npts;
        uint8 wpidx;
    }

    private enum WPFAIL {
        OK=0,
        NO = (1<<0),
        ACT = (1<<1),
        LAT = (1<<2),
        LON = (1<<3),
        ALT = (1<<4),
        P1 = (1<<5),
        P2 = (1<<6),
        P3 = (1<<7),
        FLAG = (1<<8)
    }

    private enum POSMODE {
        HOME = 1,
        PH = 2,
        RTH = 4,
        WP = 8,
        ALTH = 16,
        CRUISE = 32,
		UNDEF = 64, // emergency maybe
		LAND = 128,
    }

        // ./src/main/fc/runtime_config.h
    private enum ARMFLAGS {
        ARMED                                           = (1 << 2), // 4
        WAS_EVER_ARMED                                  = (1 << 3), // 8
        ARMING_DISABLED_FAILSAFE_SYSTEM                 = (1 << 7), // 80
        ARMING_DISABLED_NOT_LEVEL                       = (1 << 8), // 100
        ARMING_DISABLED_SENSORS_CALIBRATING             = (1 << 9), // 200
        ARMING_DISABLED_SYSTEM_OVERLOADED               = (1 << 10), // 400
        ARMING_DISABLED_NAVIGATION_UNSAFE               = (1 << 11), // 800
        ARMING_DISABLED_COMPASS_NOT_CALIBRATED          = (1 << 12), // 1000
        ARMING_DISABLED_ACCELEROMETER_NOT_CALIBRATED    = (1 << 13), // 2000
        ARMING_DISABLED_ARM_SWITCH                      = (1 << 14), // 4000
        ARMING_DISABLED_HARDWARE_FAILURE                = (1 << 15), // 8000
            // Alas, not reported by STATUS_EX
        ARMING_DISABLED_BOXFAILSAFE                     = (1 << 16), // 10000
        ARMING_DISABLED_BOXKILLSWITCH                   = (1 << 17), // 20000
        ARMING_DISABLED_RC_LINK                         = (1 << 18), // 40000
        ARMING_DISABLED_THROTTLE                        = (1 << 19), // 80000
        ARMING_DISABLED_CLI                             = (1 << 20), // 100000
        ARMING_DISABLED_CMS_MENU                        = (1 << 21), // 200000
        ARMING_DISABLED_OSD_MENU                        = (1 << 22), // 400000
        ARMING_DISABLED_ROLLPITCH_NOT_CENTERED          = (1 << 23), // 800000
        ARMING_DISABLED_SERVO_AUTOTRIM                  = (1 << 24), // 1000000
        ARMING_DISABLED_OOM                             = (1 << 25), // 2000000
        ARMING_DISABLED_INVALID_SETTING                 = (1 << 26), // 4000000
        ARMING_DISABLED_PWM_OUTPUT                      = (1 << 27), // 8000000
        ARMING_DISABLED_PREARM                          = (1 << 28), // 10000000
        ARMING_DISABLED_DSHOTBEEPER                     = (1 << 29), // 20000000
        ARMING_DISABLED_LANDING_DETECTED                = (1 << 30), // 40000000
        ARMING_DISABLED_OTHER                           = (1 << 31), // 80000000
    }

    enum SENSOR_STATES {
        None = 0,
        OK = 1,
        UNAVAILABLE = 2,
        UNHEALTHY = 3
    }

    private enum SATS {
        MINSATS = 6
    }

    private enum FWDS {
        NONE=0,
        LTM=1,
        minLTM=2,
        minMAV=3,
        ALL=4
    }

    private struct Varios {
        uint idx;
    }

	public struct MQI {
        Msp.Cmds cmd;
        size_t len;
        uint8 *data;
    }

	public struct Position {
        double lat;
        double lon;
        double alt;
    }

	const string? [] arm_fails = {
        null, null, "Armed",null, /*"Ever Armed"*/ null,null,null,
        "Failsafe", "Not level","Calibrating","Overload",
        "Navigation unsafe", "Compass cal", "Acc cal", "Arm switch", "Hardware failure",
        "Box failsafe", "Box killswitch", "RC Link", "Throttle", "CLI",
        "CMS Menu", "OSD Menu", "Roll/Pitch", "Servo Autotrim", "Out of memory",
        "Settings", "PWM Output", "PreArm", "DSHOTBeeper", "Landed", "Other"
    };

	const string[] SPEAKERS =  {"none", "espeak","speechd","flite","external"};

	const string [] health_states = {
        "None", "OK", "Unavailable", "Unhealthy"
    };

    const string[] sensor_names = {
        "Gyro", "Accelerometer", "Compass", "Barometer",
        "GPS", "RangeFinder", "Pitot", "OpticalFlow"
    };

    const string [] disarm_reason = {
        "None", "Timeout", "Sticks", "Switch_3d", "Switch",
        "Killswitch", "Failsafe", "Navigation", "Landing"
	};

    public enum NAVCAPS {
        NONE=0,
        WAYPOINTS=1,
        NAVSTATUS=2,
        NAVCONFIG=4,
        INAV_MR=8,
        INAV_FW=16
    }

    public enum SPK {
        Volts = 1,
        GPS = 2,
        BARO = 4,
        ELEV = 8
    }

    public enum SAY_WHAT {
        Test = 0,
        Arm = 1,
        Nav = 2
    }

	public enum OSD {
        show_mission = 1,
        show_dist = 2
    }
}
