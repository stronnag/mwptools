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

#include <stdint.h>

#define READ_SB_DISTNDEF 0xffffffff

typedef struct {
  uint32_t addr;
  int32_t alt;
  uint32_t hdg;
  uint32_t speed;
  uint32_t seen_pos;
  uint32_t srange;
  double lat;
  double lon;
  uint8_t catx;
  char name[9];
  uint64_t seen_tm;
} readsb_pb_t;

extern int decode_ac_pb(uint8_t *input_array, size_t input_length,
			readsb_pb_t **output_array, int* output_length);
