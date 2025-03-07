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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <time.h>

#include <sys/stat.h>
#include "readsb.pb-c.h"
#include "decode_readsb.h"

int decode_ac_pb(uint8_t *buf, size_t len, readsb_pb_t **acs, int* nac) {
  AircraftsUpdate *au = aircrafts_update__unpack(NULL, len, buf);
  *nac = 0;
  if(au == NULL || au->n_aircraft == 0) {
    *acs = NULL;
    return 0;
  }
  int anac = 0;
  *nac = au->n_aircraft;
  *acs = calloc(au->n_aircraft, sizeof(readsb_pb_t));
  if (acs != NULL) {
    readsb_pb_t *ac = *acs;
    for(int j = 0; j < au->n_aircraft; j++) {
      AircraftMeta *am;
      am = au->aircraft[j];
      AircraftMeta__ValidSource* vs = am->valid_source;
      if (vs->lat > 0) {
	ac->addr = am->addr;
	ac->catx = am->category;
	for(int j = 0; j < 8; j++) {
	  if (am->flight[j] > 31) {
	    ac->name[j] = am->flight[j];
	  } else {
	    ac->name[j] = 0;
	  }
	}
	ac->name[8] = 0;
	ac->lat = am->lat;
	ac->lon = am->lon;
	if(vs->altitude > 0) {
	  ac->alt = am->alt_baro;
	}
	if(vs->gs > 0) {
	  ac->speed = am->gs;
	}
	if (vs->mag_heading > 0) {
	  ac->hdg = am->mag_heading;
	}
	ac->srange = (am->distance == 0) ? READ_SB_DISTNDEF : am->distance;
	ac->seen_tm = am->seen;
	ac->seen_pos = am->seen_pos;
	anac++;
	ac++;
      }
    }
  }
  aircrafts_update__free_unpacked(au, NULL);
  return anac;
}

#ifdef TEST
int main(int argc, char **argv) {
  if (argc > 1) {
    int fd = open(argv[1], O_RDONLY);
    if (fd != -1) {
      struct stat st;
      if (fstat(fd, &st) != -1) {
	uint8_t *buf = malloc(st.st_size);
	if (buf != NULL) {
	  size_t n = read(fd, buf, st.st_size);
	  if (n == st.st_size) {
	    readsb_pb_t *acs;
	    int nac = 0;
	    int anac = decode_ac_pb(buf, n, &acs, &nac);
	    printf("nac %d, anac %d\n", nac, anac);
	    if (nac > 0) {
	      readsb_pb_t *a = acs;
	      for(int j = 0; j < anac; j++) {
		uint et = (a->catx&0xf) | (a->catx>>4)/0xa;
		printf("AM %X [%s] (%X, %d)", a->addr, a->name, a->catx, et);
		printf(" %f %f", a->lat, a->lon);
		printf(" alt:%d", a->alt);
		printf(" gspd:%u", a->speed);
		printf(" hdr:%u", a->hdg);
		time_t seen_s = a->seen_tm/1000;
		uint32_t ms = a->seen_tm%1000;
		struct tm* tm = localtime(&seen_s);
		char tbuf[32];
		strftime(tbuf, sizeof(tbuf), "%T", tm);
		printf(" seen: %s.%03d", tbuf, ms);
		printf(" pos_seen: %d\n", a->seen_pos);
		a++;
	      }
	      free (acs);
	    }
	  }
	}
	free(buf);
      }
    }
  }
  return 0;
}
#endif
