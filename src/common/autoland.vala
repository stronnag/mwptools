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

namespace FWApproach {
	const int MAXAPPROACH=17;
	const int MSPLENGTH=15;

	public struct approach {
		double appalt;
		double landalt;
		int16 dirn1;
		int16 dirn2;
		bool ex1;
		bool ex2;
		bool aref;
		bool dref;
	}

	private static approach approaches[17];

	public static void clear(int j) {
		approaches[j]={};
	}

	public static approach get(int j) {
		return approaches[j];
	}

	public static void set(int j, approach l) {
		approaches[j] = l;
	}

	public static void set_appalt(int j, double d) {
		approaches[j].appalt = d;
	}

	public static void set_landalt(int j, double d) {
		approaches[j].landalt = d;
	}

	public static void set_dirn1(int j, int16 a1) {
		approaches[j].dirn1 = a1;
	}

	public static void set_dirn2(int j, int16 a2) {
		approaches[j].dirn2 = a2;
	}

	public static void set_ex1(int j, bool e1) {
		approaches[j].ex1 = e1;
	}

	public static void set_ex2(int j, bool e2) {
		approaches[j].ex2 = e2;
	}

	public static void set_aref(int j, bool ar) {
		approaches[j].aref = ar;
	}

	public static void set_dref(int j, bool dr) {
		approaches[j].dref = dr;
	}

	public bool is_active(int j) {
		return !(approaches[j].dirn1 == 0 && approaches[j].dirn2 == 0);
	}

	public string to_string(int j) {
		return "%d a=%.2f l=%.2f d1=%d d2=%d dr=%s ar=%s".printf(j,
					   approaches[j].appalt,
					   approaches[j].landalt,
					   approaches[j].dirn1,
					   approaches[j].dirn2,
					   approaches[j].dref.to_string(),
					   approaches[j].aref.to_string());
	}

	public int8 deserialise(uint8 []buf, uint len) {
		int8 res = -1;
		uint8* rp = buf;
		if(len == FWApproach.MSPLENGTH  ) {
			uint8 idx = *rp++;
			int32 i32;
			int16 i16;
			uint8 u8;
			if (idx < FWApproach.MAXAPPROACH) {
				approach l = {};
				rp = SEDE.deserialise_i32(rp, out i32);
				l.appalt = (double)i32/100.0;
				rp = SEDE.deserialise_i32(rp, out i32);
				l.landalt = (double)i32/100.0;
				u8 = *rp++;
				l.dref = (u8 == 1);
				rp = SEDE.deserialise_i16(rp, out i16);
				l.dirn1 = i16;
				if (l.dirn1 < 0) {
					l.dirn1 = -l.dirn1;
					l.ex1 = true;
				}
				rp = SEDE.deserialise_i16(rp, out i16);
				l.dirn2 = i16;
				if (l.dirn2 < 0) {
					l.dirn2 = -l.dirn2;
					l.ex2 = true;
				}
				u8 = *rp++;
				l.aref = (u8 == 1);
				approaches[idx] = l;
				res = (int8)idx;
			}
		}
		return res;
	}

	public uint8 [] serialise(int idx) {
		uint8 []buf = new uint8[FWApproach.MSPLENGTH];
		var l = approaches[idx];
		uint8 *rp = buf;
		*rp++ = idx;
		rp = SEDE.serialise_i32(rp, ((int32)(l.appalt*100.0)));
		rp = SEDE.serialise_i32(rp, ((int32)(l.landalt*100.0)));
		*rp++ = (l.dref) ? 1 : 0;
		int16 dirn = (!l.ex1) ? l.dirn1 : -l.dirn1;
		rp = SEDE.serialise_i16(rp, dirn);
		dirn = (!l.ex2) ? l.dirn2 : -l.dirn2;
		rp = SEDE.serialise_i16(rp, dirn);
		*rp++ = (l.aref) ? 1 : 0;
		return buf;
	}
}
