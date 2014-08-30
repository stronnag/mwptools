#include <stdint.h>

struct  __attribute__ ((__packed__))  _ubx_header  {
  uint8_t preamble1;
  uint8_t preamble2;
  uint8_t msg_class;
  uint8_t msg_id;
  uint16_t length;
  };
typedef struct _ubx_header ubx_header;

struct  __attribute__ ((__packed__)) _ubx_nav_posllh {
  uint32_t time;  // GPS msToW
  int32_t longitude;
  int32_t latitude;
  int32_t altitude_ellipsoid;
  int32_t altitude_msl;
  uint32_t horizontal_accuracy;
  uint32_t vertical_accuracy;
};
typedef struct _ubx_nav_posllh ubx_nav_posllh;

struct  __attribute__ ((__packed__))  _ubx_nav_solution
{
  uint32_t time;
  int32_t time_nsec;
  int16_t week;
  uint8_t fix_type;
  uint8_t fix_status;
  int32_t ecef_x;
  int32_t ecef_y;
  int32_t ecef_z;
  uint32_t position_accuracy_3d;
  int32_t ecef_x_velocity;
  int32_t ecef_y_velocity;
  int32_t ecef_z_velocity;
  uint32_t speed_accuracy;
  uint16_t position_DOP;
  uint8_t res;
  uint8_t satellites;
  uint32_t res2;
};
typedef struct _ubx_nav_solution ubx_nav_solution;

struct  __attribute__ ((__packed__))  _ubx_nav_velned
{
  uint32_t time;  // GPS msToW
  int32_t ned_north;
  int32_t ned_east;
  int32_t ned_down;
  uint32_t speed_3d;
  uint32_t speed_2d;
  int32_t heading_2d;
  uint32_t speed_accuracy;
  uint32_t heading_accuracy;
};
typedef struct _ubx_nav_velned ubx_nav_velned;

union _ublox_buffer  {
    ubx_nav_posllh posllh;
    ubx_nav_solution solution;
    ubx_nav_velned velned;
    uint8_t xbytes[0];
};
typedef union _ublox_buffer ublox_buffer;
