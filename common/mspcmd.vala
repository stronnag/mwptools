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

public class MSP : Object {
    public enum Feature
    {
        GPS = (1 << 7),
        TELEMETRY = (1 << 10),
        CURRENT = (1 << 11)
    }

    public enum Cmds {
        API_VERSION=1,
        FC_VARIANT=2,
        FC_VERSION=3,
        BOARD_INFO=4,
        BUILD_INFO=5,
        IDENT=100,
        STATUS=101,
        RAW_IMU=102,
        MOTOR=104,
        RC=105,
        RAW_GPS=106,
        COMP_GPS=107,
        ATTITUDE=108,
        ALTITUDE=109,
        RC_TUNING=111,
        SET_RC_TUNING=204,
        PID=112,
        MISC=114,
        CONTROL=120,
        SET_RAW_RC=200,
        SET_PID=202,
        ACC_CALIBRATION=205,
        MAG_CALIBRATION=206,
        EEPROM_WRITE=250,
        NAV_STATUS = 121,
        NAV_CONFIG = 122,
        WP = 118,
        RADIO = 199,
        SET_NAV_CONFIG = 215,
        SET_HEAD = 211,
        SET_MISC = 207,
        SET_WP = 209,
        ANALOG = 110,
        BOX = 113,
        SET_BOX = 203,
        BOXNAMES = 116,
        BOXIDS = 119,
        SELECT_SETTING=210,
        GPSSVINFO = 164,
        GPSSTATISTICS = 166,
        WP_MISSION_LOAD = 18,      // Load mission from NVRAM
        WP_MISSION_SAVE = 19,
        WP_GETINFO = 20,
            // Cleanflight extensions
        MODE_RANGES = 34, // FC out message Returns all mode ranges
        SET_MODE_RANGE = 35,   // FC in message Sets a single mode range
        FEATURE = 36,
        REBOOT = 68,
        ACTIVEBOXES = 113,
        NAV_POSHOLD = 12,
        SET_NAV_POSHOLD = 13,
        FW_CONFIG = 23,
        SET_FW_CONFIG = 24,
        STATUS_EX = 150,
        SENSOR_STATUS = 151,
        BLACKBOX_CONFIG = 80,

        DATAFLASH_SUMMARY = 70,
        DATAFLASH_READ = 71,
        DATAFLASH_ERASE = 72,

        CALIBRATE_ACC=205,
        CALIBRATE_MAG=206,

        RTC =  246,
        SET_RTC = 247,
        DEBUGMSG = 253,
		NAME = 10,

        MSPV2 = 255,
        COMMON_TZ = 0x1001,
        COMMON_SET_TZ = 0x1002,
        COMMON_SETTING = 0x1003,
        COMMON_SET_SETTING = 0x1004,

        INAV_STATUS = 0x2000,
		ANALOG2 = 0x2002,
		INAV_MIXER = 0x2010,

	    BLACKBOX_CONFIGv2 = 0x201A,

        LTM_BASE  = 0x10000,
        TS_FRAME = (LTM_BASE + 'S'),
        TA_FRAME = (LTM_BASE + 'A'),
        TG_FRAME = (LTM_BASE + 'G'),
        TO_FRAME = (LTM_BASE + 'O'),
        TN_FRAME = (LTM_BASE + 'N'),
        TX_FRAME = (LTM_BASE + 'X'),
        Ta_FRAME = (LTM_BASE + 'a'), // private, amps message
        Tq_FRAME = (LTM_BASE + 'q'), // private, quit message
        Tx_FRAME = (LTM_BASE + 'x'), // private, quit message

        MAV_BASE  = 0x20000,
        MAVLINK_MSG_ID_HEARTBEAT = (MAV_BASE+0),
        MAVLINK_MSG_ID_SYS_STATUS = (MAV_BASE+1),
        MAVLINK_MSG_GPS_RAW_INT = (MAV_BASE+24),
        MAVLINK_MSG_ATTITUDE = (MAV_BASE+30),
        MAVLINK_MSG_GPS_GLOBAL_INT = (MAV_BASE+33),
        MAVLINK_MSG_RC_CHANNELS_RAW = (MAV_BASE+35),
        MAVLINK_MSG_GPS_GLOBAL_ORIGIN = (MAV_BASE+49),
        MAVLINK_MSG_VFR_HUD = (MAV_BASE+74),
        MAVLINK_MSG_ID_RADIO = (MAV_BASE+166),
        MAVLINK_MSG_ID_RADIO_STATUS = (MAV_BASE+109),

	// Added by WX4CB to test crossfire
	MAVLINK_MSG_ID_BATTERY_STATUS = (MAV_BASE + 147),
        NFO_WP = 0x30000,
        INVALID = 0xfffff
    }

    public enum Sensors
    {
        ACC =    (1 << 0),
        BARO =   (1 << 1),
        MAG =    (1 << 2),
        GPS =    (1 << 3),
        SONAR =  (1 << 4),
        OPFLOW = (1 << 5),
        PITOT =  (1 << 6),
        OK =     (1 << 15);

        public string to_string() {
        switch (this) {
            case ACC:
                return "Acc";

            case BARO:
                return "Baro";

            case MAG:
                return "Mag";

            case GPS:
                return "GPS";

            case SONAR:
                return "Sonar";

            default:
                assert_not_reached();
        }
			}

        public static Sensors[] all() {return { ACC, BARO, MAG, GPS, SONAR
            };
				}
			}

    public enum Action {
        UNASSIGNED=0,
        WAYPOINT,
        POSHOLD_UNLIM,
        POSHOLD_TIME,
        RTH,
        SET_POI,
        JUMP,
        SET_HEAD,
        LAND
    }

    private const string[] mrtypes = {
            "", "TRI", "QUADP","QUADX", "BI",
            "GIMBAL","Y6","HEX6","FLYING_WING",
            "Y4", "HEX6X", "OCTOX8", "OCTOFLATP", "OCTOFLATX",
            "AIRPLANE", "HELI_120_CCPM", "HELI_90_DEG", "VTAIL4",
            "HEX6H", "PPM_TO_SERVO", "DUALCOPTER", "SINGLECOPTER",
            "ATAIL4", "CUSTOM", "CUSTOMAIRPLANE", "CUSTOMTRI"
    };

    private const string[] pidnames = {
            "ROLL", "PITCH", "YAW", "ALT", "POS", "POSR", "NAVR",
            "LEVEL", "MAG", "VEL"  };
    private const string[] wp_name = {
            "UNASSIGNED", "WAYPOINT","POSHOLD_UNLIM",
            "POSHOLD_TIME", "RTH","SET_POI","JUMP", "SET_HEAD","LAND" };

    private const string[] gps_modes =  {
        "None",
        "PosHold",
        "RTH",
        "Mission" };

    private const string[] nav_states =  {
        "None",			// 0
        "RTH Start",           	// 1
        "RTH Interrupted. Machine drifting",		// 2
        "PosHold infinite",	// 3
        "PosHold timed",	// 4
        "WP Enroute",		// 5
        "Process next",		// 6
        "Jump",			// 7
        "Start Land",		// 8
        "Land in Progress",	// 9
        "Landed",		// 10
        "Settling before land", // 11
        "Start descent",		// 12
		"Hover above home",		// 13
		"Emergency landing"		// 14
    };

    private const string[] nav_errors =  {
        "Navigation system is working", // 0
        "Next waypoint distance is more than the safety limit. Aborting mission", //1
        "GPS reception is compromised - pausing mission. COPTER IS ADRIFT!", //2
        "Error while reading next waypoint from memory. Aborting mission", //3
        "Mission Finished" , //4
        "Waiting for timed position hold", //5
        "Invalid Jump target detected. Aborting mission", //6
        "Invalid Mission Step Action code detected. Aborting mission", //7
        "Waiting to reach return to home altitude", //8
        "GPS fix lost. Mission aborted - COPTER IS ADRIFT!", //9
        "Copter is disarmed. Navigation engine disabled", //10
        "Landing is in progress. Check attitude if possible" //11
    };

    private const string [] ltm_modes =
    {
        "Manual", 		// 0
        "Acro",			// 1
        "Angle",	// 2
        "Horizon",		// 3
        "Acro",			// 4
        "Stabilized1",		// 5
        "Stabilized2",		// 6
        "Stabilized3", 		// 7
        "Altitude Hold",	// 8
        "GPS Hold",	// 9
        "Waypoints",	// 10
        "Head free", // 11
        "Circle",		// 12
        "Return Home",			// 13
        "Follow me",		// 14
        "Land",			// 15
        "Fly by wire A",	// 16
        "Fly by wire B",	// 17
        "Cruise",		// 18
        "Nav mode undefined",   // 19
		"Launch", //20
		"Autotune" // 21
    };


    private const string [] bb_disarm_reasons =
    {
        "None",
        "Timeout",
        "Sticks",
        "Switch_3D",
        "Switch",
        "Killswitch",
        "Failsafe",
        "Navigation"
    };

    private static HashTable<string, MSP.Action> wp_hash;

    public static string gps_mode(uint8 nmode)
    {
        if (nmode < gps_modes.length)
            return gps_modes[nmode];
        else
            return "Unknown";
    }

    public static string bb_disarm(uint8 reason)
    {
        if (reason < bb_disarm_reasons.length)
            return bb_disarm_reasons[reason];
        else
            return "Unknown";
    }

    public static string nav_state(uint8 nstat)
    {
        if (nstat < nav_states.length)
            return nav_states[nstat];
        else
            return "Unknown";
    }

    public static string nav_error(uint8 nerr)
    {
        if (nerr < nav_errors.length)
            return nav_states[nerr];
        else
            return "Unknown";
    }

    public static string ltm_mode (uint8 nst)
    {
        if (nst < ltm_modes.length)
            return ltm_modes[nst];
        else
            return "Unknown";
    }

    public static int find_model(string mrname)
    {
        int n = 0;
        foreach(var mr in mrtypes)
        {
            if(mr == mrname)
            {
                return n;
            }
            n++;
        }
        return 0;
    }


    public static string get_mrtype(uint typ)
    {
        if (typ < mrtypes.length)
            return mrtypes[typ];
        else
            return "Unknown";
    }

    public static string get_pidname(uint typ)
    {
        if (typ < pidnames.length)
            return pidnames[typ];
        else
            return "Unknown";
    }

    public static string get_wpname(MSP.Action idx)
    {
        if (idx >= wp_name.length)
            idx= 0;
        return wp_name[idx];
    }

    public static MSP.Action lookup_name(string xs)
    {
        if(wp_hash == null)
        {
            wp_hash = new HashTable<string, MSP.Action> (str_hash, str_equal);
            for (var n = MSP.Action.UNASSIGNED; n <= MSP.Action.LAND; n += 1)
            {
                wp_hash.insert(get_wpname(n), n);
            }
        }
        return wp_hash.get(xs);
    }
}
