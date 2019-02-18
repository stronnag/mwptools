/*
 * MSP structure definitions via VAPI for 'C' packed attributes
 */

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_IDENT {
    uint8 version;
    uint8 multitype;
    uint8 msp_version;
    uint32 capability;
}


[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_STATUS {
    uint16 cycle_time;
    uint16 i2c_errors_count;
    uint16 sensor;
    uint32 flag;
    uint8 global_conf;
}

[CCode (cheader_filename = "mspmsg.h")]
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

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_ALTITUDE {
    int32 estalt;
    int16 vario;
}

[CCode (cheader_filename = "mspmsg.h")]
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

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_ATTITUDE
{
    int16 angx;
    int16 angy;
    int16 heading;
}

[CCode (cheader_filename = "mspmsg.h")]
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

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_NAV_STATUS
{
    public uint8 gps_mode;
    public uint8 nav_mode;
    public uint8 action;
    public uint8 wp_number;
    public uint8 nav_error;
    public uint16 target_bearing;
}

[CCode (cheader_filename = "mspmsg.h")]
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

[CCode (cheader_filename = "mspmsg.h")]
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

[CCode (cheader_filename = "mspmsg.h")]
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

[CCode (cheader_filename = "mspmsg.h")]
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

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_COMP_GPS
{
    public uint16 range;
    public int16 direction;
    public uint8 update;
}

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_ANALOG
{
    public uint8  vbat;
    public uint16 powermetersum;
    public uint16 rssi;
    public uint16 amps;
}


[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_NAV_POSHOLD
{
    public uint8 nav_user_control_mode;
    public uint16 nav_max_speed;
    public uint16 nav_max_climb_rate;
    public uint16 nav_manual_speed;
    public uint16 nav_manual_climb_rate;
    public uint8 nav_mc_bank_angle;
    public uint8 nav_use_midthr_for_althold;
    public uint16 nav_mc_hover_thr;
    public uint8 reserved[8];
}

[CCode (cheader_filename = "mspmsg.h")]
public struct LTM_GFRAME
{
    public int32 lat;
    public int32 lon;
    public uint8 speed;
    public int32 alt;
    public uint8 sats;
}

[CCode (cheader_filename = "mspmsg.h")]
public struct LTM_AFRAME
{
    public int16 pitch;
    public int16 roll;
    public int16 heading;
}

[CCode (cheader_filename = "mspmsg.h")]
public struct LTM_SFRAME
{
    public uint16 vbat;
    public uint16 vcurr;
    public uint8 rssi;
    public uint8 airspeed;
    public uint8 flags;
}
[CCode (cheader_filename = "mspmsg.h")]
public struct LTM_XFRAME
{
    public uint16 hdop;
    public uint8 sensorok;
    public uint8 ltm_x_count;
    public uint8 disarm_reason;
    public uint8 spare;
}

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_WP_GETINFO
{
    public uint8 wp_cap;
    public uint8 max_wp;
    public uint8 wps_valid;
    public uint8 wp_count;
}

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_FW_CONFIG
{
    public uint16 cruise_throttle;
    public uint16 min_throttle;
    public uint16 max_throttle;
    public uint8 max_bank_angle;
    public uint8 max_climb_angle;
    public uint8 max_dive_angle;
    public uint8 pitch_to_throttle;
    public uint16 loiter_radius;
}

[CCode (cheader_filename = "mspmsg.h")]
public struct MSP_GPSSTATISTICS
{
    public uint16 last_message_dt;
    public uint32 errors;
    public uint32 timeouts;
    public uint32 packet_count;
    public uint16 hdop;
    public uint16 eph;
    public uint16 epv;
}
