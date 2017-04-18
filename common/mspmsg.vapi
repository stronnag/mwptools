/*
 * MSP structure definitions via VAPI for 'C' packed attributes
 */

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_IDENT {
    uint8 version;
    uint8 multitype;
    uint8 msp_version;
    uint32 capability;
}


[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_STATUS {
    uint16 cycle_time;
    uint16 i2c_errors_count;
    uint16 sensor;
    uint32 flag;
    uint8 global_conf;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_MISC {
    uint16 intPowerTrigger1;
    uint16 conf_minthrottle;
    uint16 maxthrottle;
    uint16 mincommand;
    uint16 failsafe_throttle;
    uint16 plog_arm_counter;
    uint32 plog_lifetime;
    int16 conf_mag_declination;
    uint8 conf_vbatscale;
    uint8 conf_vbatlevel_warn1;
    uint8 conf_vbatlevel_warn2;
    uint8 conf_vbatlevel_crit;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_ALTITUDE {
    int32 estalt;
    int16 vario;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_RAW_GPS
{
    uint8   gps_fix;
    uint8   gps_numsat;
    int32   gps_lat;
    int32   gps_lon;
    int16   gps_altitude;
    uint16  gps_speed;
    uint16  gps_ground_course;
    uint16  gps_hdop;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_ATTITUDE
{
    int16 angx;
    int16 angy;
    int16 heading;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_WP
{
    public uint8 wp_no;
    public uint8 action;
    public int32 lat;
    public int32 lon;
    public int32 altitude;
    public int16 p1;
    public uint16 p2;
    public uint16 p3;
    public uint8 flag;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_NAV_STATUS
{
    public uint8 gps_mode;
    public uint8 nav_mode;
    public uint8 action;
    public uint8 wp_number;
    public uint8 nav_error;
    public uint16 target_bearing;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_NAV_CONFIG
{
    public uint8 flag1;
    public uint8 flag2;
    public uint16 wp_radius;
    public uint16 safe_wp_distance;
    public uint16 nav_max_altitude;
    public uint16 nav_speed_max;
    public uint16 nav_speed_min;
    public uint8 crosstrack_gain;
    public uint16 nav_bank_max;
    public uint16 rth_altitude;
    public uint8 land_speed;
    public uint16 fence;
    public uint8 max_wp_number;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_RC_TUNING
{
    public uint8 rc_rate;
    public uint8 rc_expo;
    public uint8 rollpitchrate;
    public uint8 yawrate;
    public uint8 dynthrpid;
    public uint8 throttle_mid;
    public uint8 throttle_expo;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_RC_TUNING_CF
{
    public uint8 rc_rate;
    public uint8 rc_expo;
    public uint8 rollrate;
    public uint8 pitchrate;
    public uint8 yawrate;
    public uint8 dynthrpid;
    public uint8 throttle_mid;
    public uint8 throttle_expo;
    public uint16 tpa_breakpoint;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_RADIO
{
    public uint16 rxerrors;
    public uint16 fixed_errors;
    public uint8 localrssi;
    public uint8 remrssi;
    public uint8 txbuf;
    public uint8 noise;
    public uint8 remnoise;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_COMP_GPS
{
     uint16 range;
     int16 direction;
     uint8 update;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_ANALOG
{
     uint8  vbat;
     uint16 powermetersum;
     uint16 rssi;
     uint16 amps;
}


[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_NAV_POSHOLD
{
    uint8 nav_user_control_mode;
    uint16 nav_max_speed;
    uint16 nav_max_climb_rate;
    uint16 nav_manual_speed;
    uint16 nav_manual_climb_rate;
    uint8 nav_mc_bank_angle;
    uint8 nav_use_midthr_for_althold;
    uint16 nav_mc_hover_thr;
    uint8 reserved[8];
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct LTM_GFRAME
{
    int32 lat;
    int32 lon;
    uint8 speed;
    int32 alt;
    uint8 sats;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct LTM_AFRAME
{
    int16 pitch;
    int16 roll;
    int16 heading;
}


[CCode (cheader_filename = "../common/mspmsg.h")]
public struct LTM_SFRAME
{
    int16 vbat;
    int16 vcurr;
    uint8 rssi;
    uint8 airspeed;
    uint8 flags;
}
[CCode (cheader_filename = "../common/mspmsg.h")]
public struct LTM_XFRAME
{
    uint16 hdop;
    uint8 sensorok;
    uint8 ltm_x_count;
    uint8 disarm_reason;
    uint8 spare;
}

[CCode (cheader_filename = "../common/mspmsg.h")]
public struct MSP_WP_GETINFO
{
    uint8 wp_cap;
    uint8 max_wp;
    uint8 wps_valid;
    uint8 wp_count;
}
