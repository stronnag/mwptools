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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
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

	const uint TIMINTVL     = 10;              // 10 milliseconds
	const uint STATINTVL    = ( 1000/TIMINTVL); //  1 sec, status update
	const uint USATINTVL    = ( 2000/TIMINTVL); //  2 sec, change in sats message
	const uint MAVINTVL     = ( 2500/TIMINTVL); //  2.5 sec, push telemetry t/o
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

	[Flags]
	public enum MspRC {
		OFF=0,
		ON=1,
		GET=2,
		SET=4,
		MAP=8,
		ACT=0x80,
	}

	public enum ShumateHotspot {
		NONE=0,
		XYALIGN=1,
		HOTSPOT=2
	}

	[Flags]
	public enum CloseCheck {
		NONE=0,
		MISSION=1,
		SERIAL=2,
		MISSIONX=0x10,
		SERIALX=0x20,
	}

	[Flags]
	public enum WPS {
        isINAV,
        isFW,
        hasJUMP,
        hasPHT,
        hasLAND,
        hasPOI,
    }

    public enum SERSTATE {
        NONE=0,
        NORMAL,
        POLLER,
		SET_WP,
		GET_WP,
		EXTRA_WP,
		MISC_BULK,
        TELEM,
        TELEM_SP,
		MISC_WORK,
    }

	[Flags]
    public enum DebugFlags {
        NONE=0,
        WP,         // 1
        INIT,       // 2
        MSP,		// 4
        ADHOC,		// 8
        RADAR,		// 16
        OTXSTDERR,	// 32
		SERIAL,		// 64
		VIDEO,		// 128
		GCSLOC,		// 256
		LOSANA,		// 512
		RDRLIST,	// 1024
		MAPS,       // 2048
		MAVLINK,    // 4096
    }

	[Flags]
    private enum SAT_FLAGS {
        NONE=0,
        NEEDED,
        URGENT,
        BEEP
    }

	[Flags]
    private enum Player {
        NONE = 0,
        MWP = 1,
        BBOX = 2,
        OTX = 4,
        FL2LTM = 8,
        RAW = 0x10,
		SQL = 0x20,
        FAST_MASK = 0x80,
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

	[Flags]
    private enum WPDL {
        IDLE=0,
        DOWNLOAD,
        REPLACE,
        POLL,
        REPLAY,
        SAVE_EEPROM,
        GETINFO,
        CALLBACK,
        CANCEL,
		SET_ACTIVE,
		SAVE_ACTIVE,
		RESET_POLLER,
		KICK_DL,
        FOLLOW_ME,
		SAVE_FWA,
		REBOOT,
		ACTIVE,
    }

    private struct WPMGR {
        MSP_WP[] wps;
        WPDL wp_flag;
        uint8 npts;
        uint8 wpidx;
    }

    private enum WPFAIL {
        OK=0,
        NO,
        ACT,
        LAT,
        LON,
        ALT,
        P1,
        P2,
        P3,
        FLAG
    }

    public enum POSMODE {
		NONE = 0,
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
		SIMULATOR_MODE_HITL                             = (1 << 4),
		SIMULATOR_MODE_SITL                             = (1 << 5),
        ARMING_DISABLED_GEOZONE                 		= (1 << 6), // 40
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

    public enum FWDS {
        NONE=0,
        LTM=1,
        minLTM=2,
        minMAV=3,
        ALL=4,
		MSP1=5,
		MSP2=6,
		MAV1=7,
		MAV2=8
    }

    private struct Varios {
        uint idx;
    }

	public struct Position {
        double lat;
        double lon;
        double alt;
    }

	const string? [] arm_fails = {
        null, null, "Armed",null, /*"Ever Armed"*/ null,null,"Geozone",
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

	[Flags]
    public enum SPK {
        Volts,
        GPS,
        BARO,
        ELEV
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

    public enum Vehicle {
        UNDEFINED = 0,
        TRI = 1,
        QUADP = 2,
        QUADX = 3,
        BICOPTER = 4,
        GIMBAL = 5,
        Y6 = 6,
        HEX6 = 7,
        FLYING_WING = 8,
        Y4 = 9,
        HEX6X = 10,
        OCTOX8 = 11,
        OCTOFLATP = 12,
        OCTOFLATX = 13,
        AIRPLANE = 14,
        HELI_120_CCPM = 15,
        HELI_90_DEG = 16,
        VTAIL4 = 17,
        HEX6H = 18,
        PPM_TO_SERVO = 19,
        DUALCOPTER = 20,
        SINGLECOPTER = 21,
        ATAIL4 = 22,
        CUSTOM = 23,
        CUSTOM_AIRPLANE = 24,
        CUSTOM_TRI = 25,
        LAST;

		public bool is_fw() {
			return (this == Vehicle.FLYING_WING || this == Vehicle.AIRPLANE || this == Vehicle.CUSTOM_AIRPLANE);
		}
		public bool is_mr() {
			return !is_fw();
		}

	}

	[Flags]
	public enum MavADSBFlags {
		NONE = 0,
		LATLON = 1,
		ALTITUDE = 2,
		HEADING = 4,
		VELOCITY = 8,
		CALLSIGN = 0x10,
		IDENT = 0x20,
		SIMULATED = 0x40,
		VERTVELOCITY = 0x80,
		BARO = 0x100,
		UAT = 0x8000,
	}
}
