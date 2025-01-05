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
	public double lat ;
	public double lon ;
	public double alt ;
	public double hdop ;
	public double cog ;
	public double gspeed ;
	public uint8 nsats ;
	public uint8 fix ;
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
}

public struct OriginData {
	public double lat ;
	public double lon ;
	public double alt ;
	public void annul() {
		lat = 0.0;
		lon = 0.0;
		alt = 0.0;
	}
}

public struct CompData {
	public int  range ;
	public int  bearing ;
	public void annul() {
		range = 0;
		bearing = 0;
	}
}

public struct AltData {
	public double alt ; // {get; construct set;}   // m
	public double vario ; // {get; construct set;} // m/s
	public void annul() {
		alt = 0;
		vario = 0;
	}
}

public struct AttiData {
	public int angx ;
	public int angy ;
	public int yaw ;
	public void annul() {
		angx = 0;
		angy = 0;
		yaw = 0;
	}
}

public struct WindData {
	public int16 w_x ;
	public int16 w_y ;
	public int16 w_z ;
	public void annul() {
		w_x = 0;
		w_y = 0;
		w_z = 0;
	}
}

public struct  PowerData {
	public float volts ;
	public int mah ;
	public void annul() {
		volts = 0;
		mah = 0;
	}
}

public struct RSSIData  {
	public int rssi ;
	public void annul() {
		rssi = 0;
	}
}

public struct StateData {
	public uint8 state ;
	public uint8 navmode ;
	public uint8 ltmstate ;
	public uint8 wpno ;
	public void annul() {
		state = 0;
		navmode = 0;
		ltmstate = 0;
		wpno = 0;
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
	public Object r;
}
