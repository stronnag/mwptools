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

namespace Flysky {
	public struct Telem {
		int32 mask;
		int status;
		double vbat;
		double curr;
		int rssi;
		int heading;
		int alt;
		int homedirn;
		int homedist;
		int cog;
		int ilat;
		int ilon;
		int galt;
		double speed;
	}

	enum Func {
		VBAT = 1,
		STATUS = 3,
		HEADING = 4,
		CURR = 5,
		ALT = 6,
		HOMEDIRN = 7,
		HOMEDIST = 8,
		COG = 9,
		GALT = 10,
		LAT1 = 11,
		LON1 = 12,
		LAT0 = 13,
		LON0 = 14,
		SPEED = 15,
	}
	private const string[] modemap = {"Manual","Acro","Horizon","Angle","WP", "AH", "PH",
                "RTH", "Launch", "Failsafe"};

	public void show_telem(Telem telem) {
		int mode = telem.status % 10;
		int hdop = (telem.status % 100) / 10;
		int nsat = (telem.status / 1000);
		hdop = hdop*10 + 1;
		int fix = 0;
		bool home = false;
		int ifix = (telem.status % 1000) / 100;
		if (ifix > 4) {
			home = true;
			ifix =- 5;
		}
		fix = ifix & 3;
		stdout.printf("Status %d, Mode %s (%d) , nsat %d, fix %d, hdop %d, home %s\n",
					  telem.status, modemap[mode], mode, nsat, fix, hdop, home.to_string());
		stdout.printf("VBat: %.2f V\n", telem.vbat);
		stdout.printf("RSSI: %d %%\n", telem.rssi);
		stdout.printf("Alt: %d m\n", telem.alt);
		stdout.printf("HDirn: %d deg\n", telem.homedirn);
		stdout.printf("HDist: %d m\n", telem.homedist);
		stdout.printf("Cog: %d deg\n", telem.cog);
		stdout.printf("Hdr: %d deg\n", telem.heading);
		stdout.printf("lat: %f \n", (double)telem.ilat/1e7);
		stdout.printf("lon: %f \n", (double)telem.ilon/1e7);
		stdout.printf("galt: %d m\n", telem.galt);
		stdout.printf("speed: %.1f m/s\n", telem.speed);
	}

	public bool decode(uint8[]buf, out Telem telem) {
		uint8 *bp = buf;
		uint16 val;
        telem = {};
		telem.rssi = (*bp * 1023)/255;
		bp++;
		for(var s = 0; s < 7; s++) {
			uint8 id = bp[0];
			uint8 sensid = bp[1];
			if (id == 0xff) {
				return (telem.mask != 0);
			}
			bp = SEDE.deserialise_u16(bp+2, out val);
			switch (sensid) { // instance
			case 1:
				telem.vbat = val/100.0;
				break;
			case 3:
				telem.status = val;
				break;
			case 4:
				telem.heading = val / 100;
				break;
			case 5:
				telem.curr = val/100.0;
				break;
			case 6:
				telem.alt = val/100;
				break;
			case 7:
				telem.homedirn = val;
				break;
			case 8:
				telem.homedist = val;
				break;
			case 9:
				telem.cog = (int16)val;
				break;
			case 10:
				telem.galt = (int16)val;
				break;
			case 11:
				telem.ilat += 10*(int16)val;
				break;
			case 12:
				telem.ilon += 10*(int16)val;
				break;
			case 13:
				telem.ilat += 100000 * (int16)val;
				break;
			case 14:
				telem.ilon += 100000 * (int16)val;
				break;
			case 15:
				telem.speed = val/3.6;
				break;
			case 255:
				return (telem.mask != 0);
			}
			telem.mask |= (1 <<  sensid);
		}
		return false;
	}
}
