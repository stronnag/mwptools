#include <stdint.h>

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

struct  __attribute__ ((__packed__)) _ubx_nav_pvt
{
    uint32_t time; // GPS msToW
    uint16_t year;
    uint8_t month;
    uint8_t day;
    uint8_t hour;
    uint8_t min;
    uint8_t sec;
    uint8_t valid;
    uint32_t tAcc;
    int32_t nano;
    uint8_t fix_type;
    uint8_t fix_status;
    uint8_t reserved1;
    uint8_t satellites;
    int32_t longitude;
    int32_t latitude;
    int32_t altitude_ellipsoid;
    int32_t altitude_msl;
    uint32_t horizontal_accuracy;
    uint32_t vertical_accuracy;
    int32_t ned_north;
    int32_t ned_east;
    int32_t ned_down;
    int32_t speed_2d;
    int32_t heading_2d;
    uint32_t speed_accuracy;
    uint32_t heading_accuracy;
    uint16_t position_DOP;
    uint16_t reserved2;
    uint16_t reserved3;
};
typedef struct _ubx_nav_pvt ubx_nav_pvt;

struct  __attribute__ ((__packed__))  _ubx_nav_timeutc
{
  uint32_t itow;  // GPS msToW
  uint32_t tacc;
  int32_t  nano;
  uint16_t year;
  uint8_t month;
  uint8_t day;
  uint8_t hour;
  uint8_t min;
  uint8_t sec;
  uint8_t valid;
};
typedef struct _ubx_nav_timeutc ubx_nav_timeutc;

struct  __attribute__ ((__packed__))  _ubx_nav_svitem
{
    uint8_t chn;
    uint8_t svid;
    uint8_t flags;
    uint8_t quality;
    uint8_t cno;
    int8_t elev;
    int16_t azim;
    uint32_t prRes;
};
typedef struct _ubx_nav_svitem ubx_nav_svitem;

struct  __attribute__ ((__packed__))  _ubx_nav_svinfo
{
  uint32_t itow;  // GPS msToW
  uint8_t numch;
  uint8_t globalflags;
  uint8_t res1;
  uint8_t res2;
  ubx_nav_svitem svitems[];
};
typedef struct _ubx_nav_svinfo ubx_nav_svinfo;

union _ublox_buffer  {
    ubx_nav_posllh posllh;
    ubx_nav_solution solution;
    ubx_nav_velned velned;
    ubx_nav_timeutc timeutc;
    ubx_nav_pvt pvt;
    ubx_nav_svinfo svinfo;
    uint8_t xbytes[2048];
};
typedef union _ublox_buffer ublox_buffer;
