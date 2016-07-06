public class Mav : Object
{
    public enum Cmds
    {
        MAVLINK_MSG_ID_HEARTBEAT = 0,
        MAVLINK_MSG_ID_SYS_STATUS = 1,
        MAVLINK_MSG_GPS_RAW_INT = 24,
        MAVLINK_MSG_ATTITUDE = 30,
        MAVLINK_MSG_GPS_GLOBAL_INT = 33,
        MAVLINK_MSG_RC_CHANNELS_RAW = 35,
        MAVLINK_MSG_GPS_GLOBAL_ORIGIN = 49,
        MAVLINK_MSG_VFR_HUD = 74,
        MAVLINK_MSG_ID_RADIO = 166
    }

    public enum SYS_STATUS_SENSOR
    {
        MAV_SYS_STATUS_SENSOR_3D_GYRO=1, /* 0x01 3D gyro | */
        MAV_SYS_STATUS_SENSOR_3D_ACCEL=2, /* 0x02 3D accelerometer | */
        MAV_SYS_STATUS_SENSOR_3D_MAG=4, /* 0x04 3D magnetometer | */
        MAV_SYS_STATUS_SENSOR_ABSOLUTE_PRESSURE=8, /* 0x08 absolute pressure | */
        MAV_SYS_STATUS_SENSOR_DIFFERENTIAL_PRESSURE=16, /* 0x10 differential pressure | */
        MAV_SYS_STATUS_SENSOR_GPS=32, /* 0x20 GPS | */
        MAV_SYS_STATUS_SENSOR_OPTICAL_FLOW=64, /* 0x40 optical flow | */
        MAV_SYS_STATUS_SENSOR_VISION_POSITION=128, /* 0x80 computer vision position | */
        MAV_SYS_STATUS_SENSOR_LASER_POSITION=256, /* 0x100 laser based position | */
        MAV_SYS_STATUS_SENSOR_EXTERNAL_GROUND_TRUTH=512, /* 0x200 external ground truth (Vicon or Leica) | */
        MAV_SYS_STATUS_SENSOR_ANGULAR_RATE_CONTROL=1024, /* 0x400 3D angular rate control | */
        MAV_SYS_STATUS_SENSOR_ATTITUDE_STABILIZATION=2048, /* 0x800 attitude stabilization | */
        MAV_SYS_STATUS_SENSOR_YAW_POSITION=4096, /* 0x1000 yaw position | */
        MAV_SYS_STATUS_SENSOR_Z_ALTITUDE_CONTROL=8192, /* 0x2000 z/altitude control | */
        MAV_SYS_STATUS_SENSOR_XY_POSITION_CONTROL=16384, /* 0x4000 x/y position control | */
        MAV_SYS_STATUS_SENSOR_MOTOR_OUTPUTS=32768, /* 0x8000 motor outputs / control | */
        MAV_SYS_STATUS_SENSOR_RC_RECEIVER=65536, /* 0x10000 rc receiver | */
        MAV_SYS_STATUS_SENSOR_3D_GYRO2=131072, /* 0x20000 2nd 3D gyro | */
        MAV_SYS_STATUS_SENSOR_3D_ACCEL2=262144, /* 0x40000 2nd 3D accelerometer | */
        MAV_SYS_STATUS_SENSOR_3D_MAG2=524288, /* 0x80000 2nd 3D magnetometer | */
        MAV_SYS_STATUS_GEOFENCE=1048576, /* 0x100000 geofence | */
        MAV_SYS_STATUS_AHRS=2097152, /* 0x200000 AHRS subsystem health | */
        MAV_SYS_STATUS_TERRAIN=4194304, /* 0x400000 Terrain subsystem health | */
        MAV_SYS_STATUS_SENSOR_ENUM_END=4194305, /*  | */
    }

    public enum TYPE
    {
        MAV_TYPE_GENERIC=0, /* Generic micro air vehicle. | */
        MAV_TYPE_FIXED_WING=1, /* Fixed wing aircraft. | */
        MAV_TYPE_QUADROTOR=2, /* Quadrotor | */
        MAV_TYPE_COAXIAL=3, /* Coaxial helicopter | */
        MAV_TYPE_HELICOPTER=4, /* Normal helicopter with tail rotor. | */
        MAV_TYPE_ANTENNA_TRACKER=5, /* Ground installation | */
        MAV_TYPE_GCS=6, /* Operator control unit / ground control station | */
        MAV_TYPE_AIRSHIP=7, /* Airship, controlled | */
        MAV_TYPE_FREE_BALLOON=8, /* Free balloon, uncontrolled | */
        MAV_TYPE_ROCKET=9, /* Rocket | */
        MAV_TYPE_GROUND_ROVER=10, /* Ground rover | */
        MAV_TYPE_SURFACE_BOAT=11, /* Surface vessel, boat, ship | */
        MAV_TYPE_SUBMARINE=12, /* Submarine | */
        MAV_TYPE_HEXAROTOR=13, /* Hexarotor | */
        MAV_TYPE_OCTOROTOR=14, /* Octorotor | */
        MAV_TYPE_TRICOPTER=15, /* Octorotor | */
        MAV_TYPE_FLAPPING_WING=16, /* Flapping wing | */
        MAV_TYPE_KITE=17, /* Flapping wing | */
        MAV_TYPE_ONBOARD_CONTROLLER=18, /* Onboard companion controller | */
        MAV_TYPE_VTOL_DUOROTOR=19, /* Two-rotor VTOL using control surfaces in vertical operation in addition. Tailsitter. | */
        MAV_TYPE_VTOL_QUADROTOR=20, /* Quad-rotor VTOL using a V-shaped quad config in vertical operation. Tailsitter. | */
        MAV_TYPE_VTOL_RESERVED1=21, /* VTOL reserved 1 | */
        MAV_TYPE_VTOL_RESERVED2=22, /* VTOL reserved 2 | */
        MAV_TYPE_VTOL_RESERVED3=23, /* VTOL reserved 3 | */
        MAV_TYPE_VTOL_RESERVED4=24, /* VTOL reserved 4 | */
        MAV_TYPE_VTOL_RESERVED5=25, /* VTOL reserved 5 | */
        MAV_TYPE_GIMBAL=26, /* Onboard gimbal | */
        MAV_TYPE_ENUM_END=27, /*  | */
    }

    public enum AUTOPILOT
    {
        MAV_AUTOPILOT_GENERIC=0, /* Generic autopilot, full support for everything | */
        MAV_AUTOPILOT_PIXHAWK=1, /* PIXHAWK autopilot, http://pixhawk.ethz.ch | */
        MAV_AUTOPILOT_SLUGS=2, /* SLUGS autopilot, http://slugsuav.soe.ucsc.edu | */
        MAV_AUTOPILOT_ARDUPILOTMEGA=3, /* ArduPilotMega / ArduCopter, http://diydrones.com | */
        MAV_AUTOPILOT_OPENPILOT=4, /* OpenPilot, http://openpilot.org | */
        MAV_AUTOPILOT_GENERIC_WAYPOINTS_ONLY=5, /* Generic autopilot only supporting simple waypoints | */
        MAV_AUTOPILOT_GENERIC_WAYPOINTS_AND_SIMPLE_NAVIGATION_ONLY=6, /* Generic autopilot supporting waypoints and other simple navigation commands | */
        MAV_AUTOPILOT_GENERIC_MISSION_FULL=7, /* Generic autopilot supporting the full mission command set | */
        MAV_AUTOPILOT_INVALID=8, /* No valid autopilot, e.g. a GCS or other MAVLink component | */
        MAV_AUTOPILOT_PPZ=9, /* PPZ UAV - http://nongnu.org/paparazzi | */
        MAV_AUTOPILOT_UDB=10, /* UAV Dev Board | */
        MAV_AUTOPILOT_FP=11, /* FlexiPilot | */
        MAV_AUTOPILOT_PX4=12, /* PX4 Autopilot - http://pixhawk.ethz.ch/px4/ | */
        MAV_AUTOPILOT_SMACCMPILOT=13, /* SMACCMPilot - http://smaccmpilot.org | */
        MAV_AUTOPILOT_AUTOQUAD=14, /* AutoQuad -- http://autoquad.org | */
        MAV_AUTOPILOT_ARMAZILA=15, /* Armazila -- http://armazila.com | */
        MAV_AUTOPILOT_AEROB=16, /* Aerob -- http://aerob.ru | */
        MAV_AUTOPILOT_ASLUAV=17, /* ASLUAV autopilot -- http://www.asl.ethz.ch | */
        MAV_AUTOPILOT_ENUM_END=18, /*  | */
    }

    public enum MODE_FLAG
    {
        MAV_MODE_FLAG_CUSTOM_MODE_ENABLED=1, /* 0b00000001 Reserved for future use. | */
        MAV_MODE_FLAG_TEST_ENABLED=2, /* 0b00000010 system has a test mode enabled. This flag is intended for temporary system tests and should not be used for stable implementations. | */
        MAV_MODE_FLAG_AUTO_ENABLED=4, /* 0b00000100 autonomous mode enabled, system finds its own goal positions. Guided flag can be set or not, depends on the actual implementation. | */
        MAV_MODE_FLAG_GUIDED_ENABLED=8, /* 0b00001000 guided mode enabled, system flies MISSIONs / mission items. | */
        MAV_MODE_FLAG_STABILIZE_ENABLED=16, /* 0b00010000 system stabilizes electronically its attitude (and optionally position). It needs however further control inputs to move around. | */
        MAV_MODE_FLAG_HIL_ENABLED=32, /* 0b00100000 hardware in the loop simulation. All motors / actuators are blocked, but internal software is full operational. | */
        MAV_MODE_FLAG_MANUAL_INPUT_ENABLED=64, /* 0b01000000 remote control input is enabled. | */
        MAV_MODE_FLAG_SAFETY_ARMED=128, /* 0b10000000 MAV safety set to armed. Motors are enabled / running / can start. Ready to fly. | */
        MAV_MODE_FLAG_ENUM_END=129, /*  | */
    }

    public struct MAVLINK_HEARTBEAT
    {
        uint32 custom_mode; ///< A bitfield for use for autopilot-specific flags.
        uint8 type; ///< Type of the MAV (quadrotor, helicopter, etc., up to 15 types, defined in MAV_TYPE ENUM)
        uint8 autopilot; ///< Autopilot type / class. defined in MAV_AUTOPILOT ENUM
        uint8 base_mode; ///< System mode bitfield, see MAV_MODE_FLAG ENUM in mavlink/include/mavlink_types.h
        uint8 system_status; ///< System status flag, see MAV_STATE ENUM
        uint8 mavlink_version; ///< MAVLink version, not writable by user, gets added by protocol because of magic data type: uint8_t_mavlink_version
    }

    public struct MAVLINK_SYS_STATUS {
        uint32 onboard_control_sensors_present; ///< Bitmask showing which onboard controllers and sensors are present. Value of 0: not present. Value of 1: present. Indices defined by ENUM MAV_SYS_STATUS_SENSOR
        uint32 onboard_control_sensors_enabled; ///< Bitmask showing which onboard controllers and sensors are enabled:  Value of 0: not enabled. Value of 1: enabled. Indices defined by ENUM MAV_SYS_STATUS_SENSOR
        uint32 onboard_control_sensors_health; ///< Bitmask showing which onboard controllers and sensors are operational or have an error:  Value of 0: not enabled. Value of 1: enabled. Indices defined by ENUM MAV_SYS_STATUS_SENSOR
        uint16 load; ///< Maximum usage in percent of the mainloop time, (0%: 0, 100%: 1000) should be always below 1000
        uint16 voltage_battery; ///< Battery voltage, in millivolts (1 = 1 millivolt)
        int16 current_battery; ///< Battery current, in 10*milliamperes (1 = 10 milliampere), -1: autopilot does not measure the current
        uint16 drop_rate_comm; ///< Communication drops in percent, (0%: 0, 100%: 10'000), (UART, I2C, SPI, CAN), dropped packets on all links (packets that were corrupted on reception on the MAV)
        uint16 errors_comm; ///< Communication errors (UART, I2C, SPI, CAN), dropped packets on all links (packets that were corrupted on reception on the MAV)
        uint16 errors_count1; ///< Autopilot-specific errors
        uint16 errors_count2; ///< Autopilot-specific errors
        uint16 errors_count3; ///< Autopilot-specific errors
        uint16 errors_count4; ///< Autopilot-specific errors
        int8 battery_remaining; ///< Remaining battery energy: (0%: 0, 100%: 100), -1: autopilot estimate the remaining battery
    }

    public struct MAVLINK_GPS_RAW_INT
    {
        uint64 time_usec; ///< Timestamp (microseconds since UNIX epoch or microseconds since system boot)
        int32 lat; ///< Latitude (WGS84), in degrees * 1E7
        int32 lon; ///< Longitude (WGS84), in degrees * 1E7
        int32 alt; ///< Altitude (AMSL, NOT WGS84), in meters * 1000 (positive for up). Note that virtually all GPS modules provide the AMSL altitude in addition to the WGS84 altitude.
        uint16 eph; ///< GPS HDOP horizontal dilution of position in cm (m*100). If unknown, set to: UINT16_MAX
        uint16 epv; ///< GPS VDOP vertical dilution of position in cm (m*100). If unknown, set to: UINT16_MAX
        uint16 vel; ///< GPS ground speed (m/s * 100). If unknown, set to: UINT16_MAX
        uint16 cog; ///< Course over ground (NOT heading, but direction of movement) in degrees * 100, 0.0..359.99 degrees. If unknown, set to: UINT16_MAX
        uint8 fix_type; ///< 0-1: no fix, 2: 2D fix, 3: 3D fix, 4: DGPS, 5: RTK. Some applications will not use the value of this field unless it is at least two, so always correctly fill in the fix.
        uint8 satellites_visible; ///< Number of satellites visible. If unknown, set to 255
    }

    public struct MAVLINK_GPS_GLOBAL_INT
    {
        uint32 time_usec; ///< Timestamp
        int32 lat; ///< Latitude (WGS84), in degrees * 1E7
        int32 lon; ///< Longitude (WGS84), in degrees * 1E7
        int32 alt; ///< Altitude (GPS), in meters * 1000 (positive for up).
        int32 relative_alt; ///< Altitude (GPS), in meters * 1000 (positive for up).
        int16 vx;   ///< Ground X Speed (Latitude, positive north), expressed as m/s * 100
        int16 vy; ///< Ground Y Speed (Longitude, positive east), expressed as m/s * 100
        int16 vz; ///< Ground Z Speed (Altitude, positive down), expressed as m/s * 100
        uint16 hdg; ///< Vehicle heading (yaw angle) in degrees * 100, 0.0..359.99 degrees. If unknown, set to: UINT16_MAX
    }

    public struct MAVLINK_ATTITUDE
    {
        uint32 time_boot_ms; ///< Timestamp (milliseconds since system boot)
        float roll; ///< Roll angle (rad, -pi..+pi)
        float pitch; ///< Pitch angle (rad, -pi..+pi)
        float yaw; ///< Yaw angle (rad, -pi..+pi)
        float rollspeed; ///< Roll angular speed (rad/s)
        float pitchspeed; ///< Pitch angular speed (rad/s)
        float yawspeed; ///< Yaw angular speed (rad/s)
    }

    public struct MAVLINK_RC_CHANNELS
    {
        uint32 time_boot_ms; ///< Timestamp (milliseconds since system boot)
        uint16 chan1_raw; ///< RC channel 1 value, in microseconds. A value of UINT16_MAX implies the channel is unused.
        uint16 chan2_raw; ///< RC channel 2 value, in microseconds. A value of UINT16_MAX implies the channel is unused.
        uint16 chan3_raw; ///< RC channel 3 value, in microseconds. A value of UINT16_MAX implies the channel is unused.
        uint16 chan4_raw; ///< RC channel 4 value, in microseconds. A value of UINT16_MAX implies the channel is unused.
        uint16 chan5_raw; ///< RC channel 5 value, in microseconds. A value of UINT16_MAX implies the channel is unused.
        uint16 chan6_raw; ///< RC channel 6 value, in microseconds. A value of UINT16_MAX implies the channel is unused.
        uint16 chan7_raw; ///< RC channel 7 value, in microseconds. A value of UINT16_MAX implies the channel is unused.
        uint16 chan8_raw; ///< RC channel 8 value, in microseconds. A value of UINT16_MAX implies the channel is unused.
        uint8 port; ///< Servo output port (set of 8 outputs = 1 port). Most MAVs will just use one, but this allows for more than 8 servos.
        uint8 rssi; ///< Receive signal strength indicator, 0: 0%, 100: 100%, 255: invalid/unknown.
    }

    public struct MAVLINK_GPS_GLOBAL_ORIGIN
    {
        int32 latitude; ///< Latitude (WGS84), in degrees * 1E7
        int32 longitude; ///< Longitude (WGS84), in degrees * 1E7
        int32 altitude; ///< Altitude (AMSL), in meters * 1000 (positive for up)
    }

    public struct MAVLINK_VFR_HUD
    {
        float airspeed; ///< Current airspeed in m/s
        float groundspeed; ///< Current ground speed in m/s
        float alt; ///< Current altitude (MSL), in meters
        float climb; ///< Current climb rate in meters/second
        int16 heading; ///< Current heading in degrees, in compass units (0..360, 0=north)
        uint16 throttle; ///< Current throttle setting in integer percent, 0 to 100
    }

    public static uint8 mav2mw(uint8 mav)
    {
        uint8 mw;
        switch(mav)
        {
            case Mav.TYPE.MAV_TYPE_FIXED_WING:
                mw = 8;
                break;
            case Mav.TYPE.MAV_TYPE_COAXIAL:
            case Mav.TYPE.MAV_TYPE_HELICOPTER:
                mw = 15;
                break;
            case Mav.TYPE.MAV_TYPE_HEXAROTOR:
                mw = 10;
                break;
            case Mav.TYPE.MAV_TYPE_OCTOROTOR:
                mw = 11;
                break;
            case Mav.TYPE.MAV_TYPE_TRICOPTER:
                mw = 1;
                break;
            default:
                mw = 3;
                break;
        }
        return mw;
    }
}
