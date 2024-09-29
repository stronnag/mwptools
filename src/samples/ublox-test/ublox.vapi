[CCode (cheader_filename = "ublox.h")]
public struct ubx_header {
  uint8 preamble1;
  uint8 preamble2;
  uint8 msg_class;
  uint8 msg_id;
  uint16 length;
}

[CCode (cheader_filename = "ublox.h")]
public struct ubx_nav_posllh {
  uint32 time;  // GPS msToW
  int32 longitude;
  int32 latitude;
  int32 altitude_ellipsoid;
  int32 altitude_msl;
  uint32 horizontal_accuracy;
  uint32 vertical_accuracy;
}

[CCode (cheader_filename = "ublox.h")]
public struct ubx_nav_solution {
  uint32 time;
  int32 time_nsec;
  int16 week;
  uint8 fix_type;
  uint8 fix_status;
  int32 ecef_x;
  int32 ecef_y;
  int32 ecef_z;
  uint32 position_accuracy_3d;
  int32 ecef_x_velocity;
  int32 ecef_y_velocity;
  int32 ecef_z_velocity;
  uint32 speed_accuracy;
  uint16 position_DOP;
  uint8 res;
  uint8 satellites;
  uint32 res2;
}

[CCode (cheader_filename = "ublox.h")]
public struct ubx_nav_velned {
  uint32 time;  // GPS msToW
  int32 ned_north;
  int32 ned_east;
  int32 ned_down;
  uint32 speed_3d;
  uint32 speed_2d;
  int32 heading_2d;
  uint32 speed_accuracy;
  uint32 heading_accuracy;
}

[CCode (cheader_filename = "ublox.h")]
public struct ubx_nav_timeutc {
  uint32 itow;  // GPS msToW
  uint32 tacc;
  int32  nano;
  uint16 year;
  uint8 month;
  uint8 day;
  uint8 hour;
  uint8 min;
  uint8 sec;
  uint8 valid;
}


[CCode (cheader_filename = "ublox.h")]
public struct ubx_nav_pvt {
    uint32 time; // GPS msToW
    uint16 year;
    uint8 month;
    uint8 day;
    uint8 hour;
    uint8 min;
    uint8 sec;
    uint8 valid;
    uint32 tAcc;
    int32 nano;
    uint8 fix_type;
    uint8 fix_status;
    uint8 reserved1;
    uint8 satellites;
    int32 longitude;
    int32 latitude;
    int32 altitude_ellipsoid;
    int32 altitude_msl;
    uint32 horizontal_accuracy;
    uint32 vertical_accuracy;
    int32 ned_north;
    int32 ned_east;
    int32 ned_down;
    int32 speed_2d;
    int32 heading_2d;
    uint32 speed_accuracy;
    uint32 heading_accuracy;
    uint16 position_DOP;
    uint16 reserved2;
    uint16 reserved3;
}

[CCode (cheader_filename = "ublox.h")]
public struct  ubx_nav_svitem {
    uint8 chn;
    uint8 svid;
    uint8 flags;
    uint8 quality;
    uint8 cno;
    int8 elev;
    int16 azim;
    uint32 prRes;
}

[CCode (cheader_filename = "ublox.h")]
public struct  ubx_nav_svinfo {
  uint32 itow;  // GPS msToW
  uint8 numch;
  uint8 globalflags;
  uint8 res1;
  uint8 res2;
  ubx_nav_svitem svitems[32];
}

[CCode (cheader_filename = "ublox.h")]
public struct  ublox_buffer {
  ubx_nav_posllh posllh;
  ubx_nav_solution solution;
  ubx_nav_velned velned;
  ubx_nav_timeutc timeutc;
  ubx_nav_pvt pvt;
  ubx_nav_svinfo svinfo;
  uint8 xbytes[512];
}
