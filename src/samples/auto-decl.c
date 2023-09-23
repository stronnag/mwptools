#include <stdio.h>
#include <stdlib.h>
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

/* See inav
   ./src/main/navigation/navigation_declination_gen.c
   ./src/main/navigation/navigation_geo.c
*/

// Get this from inav (./src/main/navigation/navigation_declination_gen.c)
#include "navigation_declination_gen.c"

#define NAV_AUTO_MAG_DECLINATION_PRECISE 1 // defined on F4 / F7

typedef struct gpsLocation_s {
  int32_t lat; // Lattitude * 1e+7
  int32_t lon; // Longitude * 1e+7
  int32_t alt; // Altitude in centimeters (meters * 100)
} gpsLocation_t;

static float get_lookup_table_val(unsigned lat_index, unsigned lon_index) { return declination_table[lat_index][lon_index]; }

float geoCalculateMagDeclination(const gpsLocation_t *llh) // degrees units
{
  /*
   * If the values exceed valid ranges, return zero as default
   * as we have no way of knowing what the closest real value
   * would be.
   */
  const float lat = llh->lat / 10000000.0f;
  const float lon = llh->lon / 10000000.0f;

  if (lat < -90.0f || lat > 90.0f || lon < -180.0f || lon > 180.0f) {
    return 0.0f;
  }

  /* round down to nearest sampling resolution */
  int min_lat = (int)(lat / SAMPLING_RES) * SAMPLING_RES;
  int min_lon = (int)(lon / SAMPLING_RES) * SAMPLING_RES;

  /* for the rare case of hitting the bounds exactly
   * the rounding logic wouldn't fit, so enforce it.
   */

  /* limit to table bounds - required for maxima even when table spans full globe range */
  if (lat <= SAMPLING_MIN_LAT) {
    min_lat = SAMPLING_MIN_LAT;
  }

  if (lat >= SAMPLING_MAX_LAT) {
    min_lat = (int)(lat / SAMPLING_RES) * SAMPLING_RES - SAMPLING_RES;
  }

  if (lon <= SAMPLING_MIN_LON) {
    min_lon = SAMPLING_MIN_LON;
  }

  if (lon >= SAMPLING_MAX_LON) {
    min_lon = (int)(lon / SAMPLING_RES) * SAMPLING_RES - SAMPLING_RES;
  }

  /* find index of nearest low sampling point */
  const unsigned min_lat_index = (-(SAMPLING_MIN_LAT) + min_lat) / SAMPLING_RES;
  const unsigned min_lon_index = (-(SAMPLING_MIN_LON) + min_lon) / SAMPLING_RES;

  const float declination_sw = get_lookup_table_val(min_lat_index, min_lon_index);
  const float declination_se = get_lookup_table_val(min_lat_index, min_lon_index + 1);
  const float declination_ne = get_lookup_table_val(min_lat_index + 1, min_lon_index + 1);
  const float declination_nw = get_lookup_table_val(min_lat_index + 1, min_lon_index);

  /* perform bilinear interpolation on the four grid corners */

  const float declination_min = ((lon - min_lon) / SAMPLING_RES) * (declination_se - declination_sw) + declination_sw;
  const float declination_max = ((lon - min_lon) / SAMPLING_RES) * (declination_ne - declination_nw) + declination_nw;

  return ((lat - min_lat) / SAMPLING_RES) * (declination_max - declination_min) + declination_min;
}

int main(int argc, char **argv) {
  if (argc == 3) {
    gpsLocation_t llh = {0};
    float decl = 0.0;
    double latf = strtod(argv[1], NULL);
    double lonf = strtod(argv[2], NULL);
    llh.lat = (int32_t)(latf * 10000000.0);
    llh.lon = (int32_t)(lonf * 10000000.0);
    decl = geoCalculateMagDeclination(&llh);
    printf("dec = %.2f for %.6f %.6f\n", decl, latf, lonf);
  } else {
    fprintf(stderr, "auto-decl lat lon\n");
  }
  return 0;
}
