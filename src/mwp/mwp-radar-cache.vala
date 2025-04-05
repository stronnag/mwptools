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


namespace Radar {
	[Flags]
	public enum RadarSource {
		NONE = 0,
		INAV,     // 1
		TELEM,    // 2,
		MAVLINK,  // 4,
		SBS,      //  8,
		ADSBX,      //  16,
		PICO, // 32
		M_INAV = (INAV|TELEM),
		M_ADSB = (MAVLINK|SBS|ADSBX|PICO);

		public string to_string() {
			string sstr;
			if ((this & INAV) != 0) {
				sstr = "INAV";
			} else if((this & MAVLINK) != 0) {
				sstr = "MAVL";
			} else if((this & SBS) != 0) {
				sstr = "SDR";
			} else if((this & ADSBX) != 0) {
				sstr = "ADSBX";
			} else if((this & TELEM) != 0) {
				sstr = "TELEM";
			} else if((this & TELEM) != 0) {
				sstr = "PICO";
			} else {
				sstr = "UnKnown";
			}
			return sstr;
		}

		public string source_id() {
			switch(this) {
			case RadarSource.INAV:
				return "I";
			case RadarSource.TELEM:
				return "T";
			case RadarSource.MAVLINK:
				return "A";
			case RadarSource.SBS:
				return "S";
			case RadarSource.ADSBX:
				return "X";
			case RadarSource.PICO:
				return "P";
			default:
				return "?";
			}
		}
	}

	public class RadarPlot : Object {
		public uint id;
		public string name  {get; construct set;}
		public double latitude {get; construct set;}
		public double longitude  {get; construct set;}
		public double altitude  {get; construct set;}
		public double range  {get; construct set;}
		public uint16 bearing  {get; construct set;}
		public uint16 heading  {get; construct set;}
		public double speed  {get; construct set;}
		public uint lasttick;
		public uint8 state  {get; construct set;}
		public uint8 lq  {get; construct set;} // tslc for ADSB
		public uint8 source  {get; construct set;}
		public uint8 alert  {get; construct set;}
		public uint8 etype  {get; construct set;}
		public uint32 srange;
		public bool posvalid;
		public uint lastiax;
		public DateTime dt {get; construct set;}
		public DateTime lastdraw {get; construct set;}

		public RadarPlot() {
			bearing = 0xffff;
			lastiax = 0;
		}
	}

	public enum RadarAlert {
		NONE = 0,
		ALERT = 1,
		SET= 2
	}

	public class RadarCache : Object {
		public GLib.ListStore lstore;

		public RadarCache() {
			lstore = new GLib.ListStore(typeof(RadarPlot));
		}

		public bool find(uint rid, out uint pos) {
			var tmp = new RadarPlot();
			tmp.id = rid;
			return lstore.find_with_equal_func(tmp, (a,b) => {return ((RadarPlot)a).id == ((RadarPlot)b).id;}, out pos);
		}

		public bool remove(uint rid) {
			uint pos;
			if(find(rid, out pos)) {
				lstore.remove(pos);
				return true;
			}
			return false;
		}

		public bool upsert(uint k, RadarPlot v) {
			uint pos;
			v.id = k;
			bool found = find(k, out pos);
			if (!found){
				lstore.append(v);
			}
			return found;
		}

		public uint size() {
			return lstore.get_n_items();
		}

		public RadarPlot? get_item(uint pos) {
			return lstore.get_item(pos) as RadarPlot;
		}

		public RadarPlot? lookup(uint k) {
			uint pos;
			if(find(k, out pos)) {
				return lstore.get_item(pos) as RadarPlot;
			}
			return null;
		}
	}
}
