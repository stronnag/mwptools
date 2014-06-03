
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
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
public class MSP : Object
{
    public enum Cmds
    {
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
            TG_FRAME = (0x1000 + 'G'),
            TA_FRAME = (0x1000 + 'A'),
            TS_FRAME = (0x1000 + 'S')
    }

    public enum Sensors
    {
        ACC = 1,
        BARO = 2,
        MAG = 4,
        GPS=8,
        SONAR=16
    }

    public enum Action
    {
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

    private static const string[] mrtypes = {
            "", "TRI", "QUADP","QUADX", "BI",
            "GIMBAL","Y6","HEX6","FLYING_WING","Y4","HEX6X","OCTOX8",
            "OCTOFLATP","OCTOFLATX","AIRPLANE/SINGLECOPTER,DUALCOPTER",
            "HELI_120","HELI_90","VTAIL4","HEX6H" };
    private static const string[] pidnames = {
            "ROLL", "PITCH", "YAW", "ALT", "POS", "POSR", "NAVR",
            "LEVEL", "MAG", "VEL"  };
    private static const string[] wp_name = {
            "UNASSIGNED", "WAYPOINT","POSHOLD_UNLIM",
            "POSHOLD_TIME", "RTH","SET_POI","JUMP", "SET_HEAD","LAND" };

    private static const string[] gps_modes =  {
        "None",
        "PosHold",
        "RTH",
        "Mission" };

    private static const string[] nav_states =  {
        "None",			// 0
        "RTH Start",           	// 1
        "RTH Enroute",		// 2
        "PosHold infinit",	// 3
        "PosHold timed",	// 4
        "WP Enroute",		// 5
        "Process next",		// 6
        "Jump",			// 7
        "Start Land",		// 8
        "Land in Progress",	// 9
        "Landed",		// 10
        "Settling before land", // 11
        "Start descent"		// 12
    };

    private static const string[] nav_errors =  {
        "Navigation system is working",
        "Next waypoint distance is more than the safety limit, aborting mission",
        "GPS reception is compromised - pausing mission, COPTER IS ADRIFT!",
        "Error while reading next waypoint from memory, aborting mission",
        "Mission Finished" ,
        "Waiting for timed position hold",
        "Invalid Jump target detected, aborting mission",
        "Invalid Mission Step Action code detected, aborting mission",
        "Waiting to reach return to home altitude",
        "GPS fix lost, mission aborted - COPTER IS ADRIFT!",
        "Copter is disarmed, navigation engine disabled",
        "Landing is in progress, check attitude if possible"
    };

    private static HashTable<string, MSP.Action> wp_hash;

    public static string gps_mode(uint8 nmode)
    {
        if (nmode < gps_modes.length)
            return gps_modes[nmode];
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
