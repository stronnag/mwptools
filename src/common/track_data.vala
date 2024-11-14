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
}

public class  GPSData : Object {
	public double lat {get; construct set;}
	public double lon {get; construct set;}
	public double alt {get; construct set;}
	public double hdop {get; construct set;}
	public double cog {get; construct set;}
	public double gspeed {get; construct set;}
	public uint8 nsats {get; construct set;}
	public uint8 fix {get; construct set;}
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

public class OriginData : Object{
	public double lat {get; construct set;}
	public double lon {get; construct set;}
	public double alt {get; construct set;}
	public void annul() {
		lat = 0.0;
		lon = 0.0;
		alt = 0.0;
	}
}

public class  CompData : Object {
	public int  range {get; construct set;}
	public int  bearing {get; construct set;}
	public void annul() {
		range = 0;
		bearing = 0;
	}
}

public class  AltData : Object {
	public double alt {get; construct set;}   // m
	public double vario {get; construct set;} // m/s
	public void annul() {
		alt = 0;
		vario = 0;
	}
}

public class  AttiData : Object {
	public int angx {get; construct set;}
	public int angy {get; construct set;}
	public int yaw {get; construct set;}
	public void annul() {
		angx = 0;
		angy = 0;
		yaw = 0;
	}
}

public class PowerData : Object{
	public float volts {get; construct set;}
	//	public double amps {get; construct set;}
	public void annul() {
		volts = 0;
	}
}

public class RSSIData :Object {
	public int rssi {get; construct set;}
	public void annul() {
		rssi = 0;
	}
}

public class StateData :Object {
	public uint8 state {get; construct set;}
	public uint8 navmode {get; construct set;}
	public uint8 ltmstate {get; construct set;}
	public uint8 wpno {get; construct set;}
	public void annul() {
		state = 0;
		navmode = 0;
		ltmstate = 0;
		wpno = 0;
	}
}

public class TrackData : Object {
	public GPSData gps;
	public OriginData origin;
	public CompData comp;
	public PowerData power;
	public RSSIData rssi;
	public AltData alt;
	public AttiData atti;
	public StateData state;

	public  TrackData (TrackDataSet v = 0xff) {
		if( TrackDataSet.GPS in v) {
			gps = new GPSData();
		}
		if( TrackDataSet.ORIGIN in v) {
			origin = new OriginData();
		}
		if( TrackDataSet.COMP in v) {
			comp = new CompData();
		}
		if( TrackDataSet.POWER in v) {
			power = new PowerData();
		}
		if( TrackDataSet.RSSI in v) {
			rssi = new RSSIData();
		}
		if( TrackDataSet.ALT in v) {
			alt = new AltData();
		}
		if( TrackDataSet.ATTI in v) {
			atti = new AttiData();
		}
		if( TrackDataSet.STATE in v) {
			state = new StateData();
		}
	}
}
