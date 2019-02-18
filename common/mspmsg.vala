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

public struct MSP_IDENT {
    uint8 version;
    uint8 multitype;
    uint8 msp_version;
    uint32 capability;
}

public struct MSP_STATUS {
    uint16 cycle_time;
    uint16 i2c_errors_count;
    uint16 sensor;
    uint32 flag;
    uint8 global_conf;
}

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

public struct MSP_ALTITUDE {
    int32 estalt;
    int16 vario;
}

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

public struct MSP_ATTITUDE
{
    int16 angx;
    int16 angy;
    int16 heading;
}

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

public struct MSP_N32_WP
{
    public uint8 wp_no;
    public int32 lat;
    public int32 lon;
    public int32 alt;
    public int16 p1;
    public uint16 p2;
    public uint8 p3;
}

public struct MSP_NAV_STATUS
{
    public uint8 gps_mode;
    public uint8 nav_mode;
    public uint8 action;
    public uint8 wp_number;
    public uint8 nav_error;
    public uint16 target_bearing;
}

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
    public uint8 yaw_expo;
}

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

public struct MSP_COMP_GPS
{
     uint16 range;
     int16 direction;
     uint8 update;
}

public struct MSP_ANALOG
{
     uint8  vbat;
     uint16 powermetersum;
     uint16 rssi;
     uint16 amps;
}

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

public struct MSP_FW_CONFIG
{
    uint16 cruise_throttle;
    uint16 min_throttle;
    uint16 max_throttle;
    uint8 max_bank_angle;
    uint8 max_climb_angle;
    uint8 max_dive_angle;
    uint8 pitch_to_throttle;
    uint16 loiter_radius;
}

public struct LTM_GFRAME
{
    int32 lat;
    int32 lon;
    uint8 speed;
    int32 alt;
    uint8 sats;
}

public struct LTM_AFRAME
{
    int16 pitch;
    int16 roll;
    int16 heading;
}


public struct LTM_SFRAME
{
    uint16 vbat;
    uint16 vcurr;
    uint8 rssi;
    uint8 airspeed;
    uint8 flags;
}

public struct LTM_OFRAME
{
    int32 lat;
    int32 lon;
    int32 alt;
    uint8 osd;
    uint8 fix;
}

public struct LTM_XFRAME
{
    uint16 hdop;
    uint8 sensorok;
    uint8 ltm_x_count;
    uint8 disarm_reason;
    uint8 spare;
}

public struct CF_MODE_RANGES
{
    uint8 perm_id;
    uint8 auxchanid;
    uint8 startstep;
    uint8 endstep;
}

public struct MSP_WP_GETINFO
{
    uint8 wp_cap;
    uint8 max_wp;
    uint8 wps_valid;
    uint8 wp_count;
}

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

public enum MSize
{
    MSP_IDENT=7,
    MSP_STATUS=11,
    MSP_STATUS_EX=16,
    MSP2_INAV_STATUS=21,
    MSP_MISC=22,
    MSP_ALTITUDE=6,
    MSP_RAW_GPS=18,
    MSP_ATTITUDE=6,
    MSP_WP=21,
    MSP_NAV_STATUS=7,
    MSP_NAV_CONFIG=21,
    MSP_RC_TUNING=7,
    MSP_RADIO=9,
    MSP_COMP_GPS=5,
    MSP_ANALOG=7,
    LTM_GFRAME=14,
    LTM_AFRAME=6,
    LTM_SFRAME=7,
    LTM_OFRAME=14,
    LTM_NFRAME=6,
    LTM_XFRAME=6,
    MSP_GPSSTATISTICS=20
}

public enum MSPCaps
{
    CAP_PLATFORM_32BIT = (1 << 31),
    CAP_BASEFLIGHT_CONFIG = (1 << 30),
    CAP_CLEANFLIGHT_CONFIG = (1 << 29)
}

public uint8* deserialise_u64(uint8* rp, out uint64 v)
{
    uint32 u;
    rp = deserialise_u32(rp, out u);
    v = u;
    rp = deserialise_u32(rp, out u);
    v = v | ((uint64)u << 32);
    return rp;
}

public uint8* deserialise_u32(uint8* rp, out uint32 v)
{
    v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
    return rp + sizeof(uint32);
}

public uint8* deserialise_i32(uint8* rp, out int32 v)
{
    v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
    return rp + sizeof(int32);
}

public uint8* deserialise_u16(uint8* rp, out uint16 v)
{
    v = *rp | (*(rp+1) << 8);
    return rp + sizeof(uint16);
}

public uint8* deserialise_i16(uint8* rp, out int16 v)
{
    v = *rp | (*(rp+1) << 8);
    return rp + sizeof(int16);
}


public uint8 * serialise_u16(uint8* rp, uint16 v)
{
    *rp++ = v & 0xff;
    *rp++ = v >> 8;
    return rp;
}

public uint8 * serialise_i16(uint8* rp, int16 v)
{
    return serialise_u16(rp, (int16)v);
}

public uint8 * serialise_u32(uint8* rp, uint32 v)
{
    *rp++ = v & 0xff;
    *rp++ = ((v >> 8) & 0xff);
    *rp++ = ((v >> 16) & 0xff);
    *rp++ = ((v >> 24) & 0xff);
    return rp;
}

public uint8 * serialise_i32(uint8* rp, int32 v)
{
    return serialise_u32(rp, (int32)v);
}


#if UTEST
public static int main (string[] args)
{
    uint8[] raw = {1,2,3,4};
    uint8 *rp;

    uint32 v;

    rp = deserialise_u32(raw, out v);
    stdout.printf("v = %u %p %p\n", v, raw, rp);
    uint8 xraw[4];
    rp = serialise_u32(xraw,v);
    stdout.printf("xraw = %x %x %x %x\n", xraw[0], xraw[1], xraw[2], xraw[3]);
    int32 k;
    rp = deserialise_i32(raw, out k);
    stdout.printf("k = %d %p %p\n", k, raw, rp);
    rp = serialise_i32(xraw,k);
    stdout.printf("xraw = %x %x %x %x\n", xraw[0], xraw[1], xraw[2], xraw[3]);

    int16 x = -2345;
    serialise_i16(xraw,x);
    stdout.printf("xraw = %x %x\n", xraw[0], xraw[1]);
    rp = xraw;
    int16 y;
    rp = deserialise_i16(rp, out y);
    stdout.printf("y = %d\n", y);
    serialise_i16(xraw+2,y);
    stdout.printf("xraw = %x %x\n", xraw[2], xraw[3]);

    uint16 ux = 0x123;
    serialise_u16(xraw,ux);
    stdout.printf("u16 xraw = %x %x\n", xraw[0], xraw[1]);
    rp = xraw;
    uint16 uy;
    rp = deserialise_i16(rp, out uy);
    stdout.printf("uy = %d\n", uy);

    ux = 0x42;
    serialise_u16(xraw,ux);
    stdout.printf("u16 xraw = %x %x\n", xraw[0], xraw[1]);
    rp = xraw;
    rp = deserialise_i16(rp, out uy);
    stdout.printf("uy = %d\n", uy);


    k = -3;
    serialise_i32(xraw,k);
    stdout.printf("xraw = %x %x %x %x\n", xraw[0], xraw[1], xraw[2], xraw[3]);

    rp = deserialise_i32(xraw, out k);
    stdout.printf("k = %d\n", k);
    serialise_i32(xraw,k);
    stdout.printf("xraw = %x %x %x %x\n", xraw[0], xraw[1], xraw[2], xraw[3]);

    return 0;
}
#endif
