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

[Flags]
public enum TrackDataSet {
	GPS,
	ORIGIN,
	COMP,
	ALT,
	ATTI,
	POWER,
	RSSI,
	STATE,
	WIND,
}

public struct GPSData {
	public double lat ; 	// decimal degrees
	public double lon ; 	// decimal degrees
	public double alt ; 	// metres
	public double hdop ; 	// "units"
	public double cog ; 	// degress
	public double gspeed ; 	// m/s
	public uint8 nsats ; 	// number
	public uint8 fix ; 		// number
	public void annul() {
		lat = 0.0;
		lon = 0.0;
		alt = 0.0;
		hdop = 9999;
		cog = 0;
		gspeed = 0;
		nsats = 0;
		fix = 0;
	}

	public string to_string() {
		var sb = new StringBuilder("GPS: ");
		sb.append_printf("lat: %.6f, lon: %.6f, alt: %.2f, cog: %.1f, gspd: %.1f, sats: %u, fix: %u, hdop: %.1f", this.lat, this.lon, this.alt, this.cog, this.gspeed, this.nsats, this.fix, this.hdop);
		return sb.str;
	}
}


public struct OriginData {
	public double lat ;		// decimal degrees
	public double lon ;		// decimal degrees
	public double alt ;		// metres
	public void annul() {
		lat = 0.0;
		lon = 0.0;
		alt = 0.0;
	}

	public string to_string() {
		var sb = new StringBuilder("Origin: ");
		sb.append_printf("olat: %.6f, olon: %.6f, o.alt: %.2f", this.lat, this.lon, this.alt);
		return sb.str;
	}
}

public struct CompData {
	public int  range ;		// metres
	public int  bearing ;	// degress
	public void annul() {
		range = 0;
		bearing = 0;
	}
	public string to_string() {
		var sb = new StringBuilder("Comp: ");
		sb.append_printf("range: %d, bearing: %d", this.range, this.bearing);
		return sb.str;
	}
}

public struct AltData {
	public double alt ; 	// m
	public double vario ; 	// m/s
	public void annul() {
		alt = 0;
		vario = 0;
	}
	public string to_string() {
		var sb = new StringBuilder("Alt: ");
		sb.append_printf("alt %.1f, vario: %.1f", this.alt, this.vario);
		return sb.str;
	}
}

public struct AttiData {
	public int angx ;		// degrees, roll, cw +ve
	public int angy ;		// degrees, pitch down +ve
	public int yaw ;        // degrees
	public void annul() {
		angx = 0;
		angy = 0;
		yaw = 0;
	}
	public string to_string() {
		var sb = new StringBuilder("Atti: ");
		sb.append_printf("angx %d, angy: %d, yaw: %d", this.angx, this.angy, this.yaw);
		return sb.str;
	}
}

public struct WindData {
	public bool has_wind;
	public int16 w_x ;		// m/s
	public int16 w_y ;		// m/s
	public int16 w_z ;		// m/s
	public void annul() {
		has_wind = false;
		w_x = 0;
		w_y = 0;
		w_z = 0;
	}
	public string to_string() {
		var sb = new StringBuilder("Wind: ");
		sb.append_printf("ok: %s, w_x: %d, w_y: %d, w_z: %d", this.has_wind.to_string(), this.w_x, this.w_y, this.w_z);
		return sb.str;
	}
}

public struct  PowerData {
	public float volts ; 	// volts
	public int mah;			// mah
	public float amps;		// amps
	public void annul() {
		volts = 0;
		mah = 0;
		amps = 0;
	}
	public string to_string() {
		var sb = new StringBuilder("Power: ");
		sb.append_printf("volts: %.2f, mah: %d\n", this.volts, this.mah);
		return sb.str;
	}
}

public struct RSSIData  {
	public int rssi ;		// 0-100 (%)
	public void annul() {
		rssi = 0;
	}
	public string to_string() {
		var sb = new StringBuilder("RSSI: ");
		sb.append_printf("rssi: %d", this.rssi);
		return sb.str;
	}
}

public struct StateData {
	public uint8 state ;
	public uint8 gpsmode ;
	public uint8 navmode ;
	public uint8 ltmstate ;
	public uint8 wpno;
	public uint8 action;
	public uint8 sensorok ;
	public uint8 reason;

	public void annul() {
		state = 0;
		navmode = 0;
		ltmstate = 0;
		wpno = 0;
		sensorok = 0;
		reason = 0;
		gpsmode = 0;
		action = 0;
	}
	public string to_string() {
		var sb = new StringBuilder("State: ");
		sb.append_printf("state %x, ltmstate: %x, navmode: %d, wpno: %d", this.state, this.ltmstate, this.navmode, this.wpno);
		return sb.str;
	}
}

public struct TrackData {
	public GPSData gps;
	public OriginData origin;
	public CompData comp;
	public PowerData power;
	public RSSIData rssi;
	public AltData alt;
	public AttiData atti;
	public StateData state;
	public WindData wind;
	public Object r; // Telemetry private "raw" data

	public void annul_all() {
		gps.annul();
		origin.annul();
		comp.annul();
		power.annul();
		rssi.annul();
		alt.annul();
		atti.annul();
		state.annul();
		wind.annul();
	}

	public void to_log(TrackDataSet ts = 0xff) {
		MWPLog.message(to_string(ts));
	}

	public string to_string(TrackDataSet ts = 0xff) {
		var sb = new StringBuilder("Telem Data\n");
		if (TrackDataSet.GPS in ts) {
			sb.append("  ");
			sb.append(gps.to_string());
			sb.append_c('\n');
		}
		if (TrackDataSet.ORIGIN in ts) {
			sb.append("  ");
			sb.append(origin.to_string());
			sb.append_c('\n');
		}
		if (TrackDataSet.ALT in ts) {
			sb.append("  ");
			sb.append(alt.to_string());
			sb.append_c('\n');
		}
		if (TrackDataSet.COMP in ts) {
			sb.append("  ");
			sb.append(comp.to_string());
			sb.append_c('\n');
		}
		if (TrackDataSet.ATTI in ts) {
			sb.append("  ");
			sb.append(atti.to_string());
			sb.append_c('\n');
		}
		if (TrackDataSet.STATE in ts) {
			sb.append("  ");
			sb.append(state.to_string());
			sb.append_c('\n');
		}
		if (TrackDataSet.RSSI in ts) {
			sb.append("  ");
			sb.append(rssi.to_string());
			sb.append_c('\n');
		}
		if (TrackDataSet.WIND in ts) {
			sb.append("  ");
			sb.append(wind.to_string());
			sb.append_c('\n');
		}
		return sb.str;
	}
}
