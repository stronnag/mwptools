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
public struct  ublox_buffer {
  ubx_nav_posllh posllh;
  ubx_nav_solution solution;
  ubx_nav_velned velned;
  uint8 [] xbytes;
}
