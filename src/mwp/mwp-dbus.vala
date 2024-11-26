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

namespace MBus {
	internal Service svc;
	public int nwpts;

	internal uint8 nsats;
	internal uint8 fix;

	public void update_fix() {
		if (Mwp.msp.td.gps.nsats != nsats || Mwp.msp.td.gps.fix != fix) {
			nsats = Mwp.msp.td.gps.nsats;
			fix = Mwp.msp.td.gps.fix;
			svc.sats_changed(nsats, fix);
		}
	}

	internal double hlat;
	internal double hlon;

	public void update_home() {
		if (hlat != Mwp.msp.td.origin.lat || hlon != Mwp.msp.td.origin.lon) {
			hlat = Mwp.msp.td.origin.lat;
			hlon = Mwp.msp.td.origin.lon;
			svc.home_changed(hlat, hlon, (int)Mwp.msp.td.origin.alt);
		}
	}

	internal double blat;
	internal double blon;
	internal int balt;
	internal uint32 bspd;
	internal uint32 bcse;
	internal uint16 bazimuth;
	internal uint32 brange;
	internal uint32 bdirection;
	internal uint lastdbus;
	internal uint dbus_upd_ticks = 20;

	public void update_location() {
		if(svc.dbus_pos_interval == 0 || Mwp.nticks - lastdbus >= dbus_upd_ticks) {
			if(blat != Mwp.msp.td.gps.lat || blon != Mwp.msp.td.gps.lon || balt != (int)Mwp.msp.td.gps.alt) {
				blat = Mwp.msp.td.gps.lat;
				blon = Mwp.msp.td.gps.lon;
				balt = (int)Mwp.msp.td.gps.alt;
				svc.location_changed(blat, blon, balt);

				int16 tazimuth = (int16)(Math.atan2(Mwp.msp.td.gps.alt, Mwp.msp.td.comp.range)/(Math.PI/180.0));
                // Historic MW baggage ...alas
				var brg = Mwp.msp.td.comp.bearing;
				if(brg < 0)
					brg += 360;
				brg = ((brg + 180) % 360);
				if(bdirection != Mwp.msp.td.comp.bearing || brange != Mwp.msp.td.comp.range || bazimuth != tazimuth) {
					bdirection = Mwp.msp.td.comp.bearing;
					brange = Mwp.msp.td.comp.range;
					bazimuth = tazimuth;
					svc.polar_changed(brange, brg, bazimuth);
				}

				if(bspd != (uint32)Mwp.msp.td.gps.gspeed || bcse != (uint32)Mwp.msp.td.gps.cog) {
					bspd = (uint32)Mwp.msp.td.gps.gspeed;
					bcse = (uint32)Mwp.msp.td.gps.cog;
					svc.velocity_changed(bspd, bcse);
				}
				lastdbus = Mwp.nticks;
			}
		}
	}

	internal int bstate;
	internal int bmode;
	public void update_state() {
		if (bstate != Mwp.msp.td.state.state || bmode != Mwp.msp.td.state.ltmstate) {
			bstate = Mwp.msp.td.state.state;
			bmode = Mwp.msp.td.state.ltmstate;
			svc.state_changed(bstate, bmode);
		}
	}

	internal uint8 bwpno;
	public void update_wp() {
		if(bwpno != Mwp.msp.td.state.wpno) {
			bwpno = Mwp.msp.td.state.wpno;
			svc.waypoint_changed((int)bwpno);
		}
	}

	[DBus (name = "org.stronnag.mwp")]
	public class Service : Object {
		public signal void home_changed (double latitude, double longitude,int altitude);
		public signal void location_changed (double latitude, double longitude, int altitude);
		public signal void polar_changed(uint32 range, uint32 direction, uint32 azimuth);
		public signal void velocity_changed(uint32 speed, uint32 course);

		public signal void state_changed(int state, int mode);
		public signal void sats_changed(uint8 nsats, uint8 fix);
		public signal void waypoint_changed(int wp);

		public uint dbus_pos_interval { get; construct set; default = 2000;}
		public signal void quit();

		internal SourceFunc callback;

		public int get_mode_names(out string[]names) throws GLib.Error {
			string[] _names = {};
			for (var e = Msp.Ltm.MANUAL; e <= Msp.Ltm.AUTOTUNE; e = e+1) {
				var s = e.to_string();
				// MSP_LTM_ xxxx (8 bytes lead-in)
				_names += s.substring(8);
			}
			names = _names;
			return _names.length;
		}

		public void get_velocity(out uint32 speed, out uint32 course) throws GLib.Error {
			if (Mwp.msp != null && Mwp.msp.available) {
				speed = (uint32)Mwp.msp.td.gps.gspeed;
				course = (uint32)Mwp.msp.td.gps.cog;
			} else {
				speed = 0;
				course = 0;
			}
		}

		public void get_polar_coordinates(out uint32 range, out uint32 direction, out uint32 azimuth) throws GLib.Error {
			if (Mwp.msp != null && Mwp.msp.available) {
				range = Mwp.msp.td.comp.range;
				direction = Mwp.msp.td.comp.bearing;
				azimuth = MBus.bazimuth;
			} else {
				range = 0;
				direction = 0;
				azimuth = 0;
			}
		}

		public void get_home(out double latitude, out double longitude, out int32 altitude) throws GLib.Error {
			if (Mwp.msp != null && Mwp.msp.available) {
				latitude = Mwp.msp.td.origin.lat;
				longitude = Mwp.msp.td.origin.lon;
				altitude = (int32)Mwp.msp.td.origin.alt;
			} else {
				latitude = 0;
				longitude = 0;
				altitude = 0;
			}
		}

		public void get_location(out double latitude, out double longitude, out int32 altitude) throws GLib.Error {
			if (Mwp.msp != null && Mwp.msp.available) {
				latitude = Mwp.msp.td.gps.lat;
				longitude = Mwp.msp.td.gps.lon;
				altitude = (int32)Mwp.msp.td.gps.alt;
			} else {
				latitude = 0;
				longitude = 0;
				altitude = 0;
			}
		}

		public void get_state(out int state, out int mode ) throws GLib.Error {
			if (Mwp.msp != null && Mwp.msp.available) {
				state = Mwp.msp.td.state.state;
				mode = Mwp.msp.td.state.ltmstate;
			} else {
				mode  = Msp.Ltm.UNDEFINED;
				state = 0;
			}
		}

		public int get_waypoint_number() throws GLib.Error {
			if (Mwp.msp != null && Mwp.msp.available) {
				return Mwp.msp.td.state.wpno;
			}
			return 0;
		}

		public void get_sats(out uint8 nsats, out uint8 fix) throws GLib.Error {
			if (Mwp.msp != null && Mwp.msp.available) {
				nsats = Mwp.msp.td.gps.nsats;
				fix = Mwp.msp.td.gps.fix;
			} else {
				nsats = 0;
				fix = 0;
			}
		}
		public uint set_mission (string mission) throws GLib.Error {
			Mission? ms = null;

			unichar c = mission.get_char(0);
			Mission []_msx;

			if(c == '<') {
				_msx = XmlIO.read_xml_string(mission, true);
			} else
				_msx = JsonIO.from_json(mission);

			if(_msx.length > 0) {
				MissionManager.msx = _msx;
				MissionManager.mdx = 0;
				ms = MissionManager.setup_mission_from_mm();
			}
			return (ms != null) ? ms.npoints : 0;
		}

		public uint load_mission (string filename) throws GLib.Error {
			var ms = MissionManager.open_mission_file(filename);
			if (ms != null) {
				return ms.npoints;
			} else {
				return 0;
			}
		}

		public void clear_mission () throws GLib.Error {
			Mwp.hard_mission_clear();
		}

		public void load_blackbox (string filename) throws GLib.Error {
			BBL.replay_bbl(filename);
		}

		public void load_mwp_log (string filename) throws GLib.Error {
			Mwp.run_replay(filename, true, Mwp.Player.MWP);
		}

		public void get_devices (out string[]devices) throws GLib.Error {
			devices = Mwp.list_combo(Mwp.dev_combox);
		}

		public async int upload_mission(bool to_eeprom) throws GLib.Error {
			var flag = Mwp.WPDL.CALLBACK|Mwp.WPDL.GETINFO|Mwp.WPDL.SAVE_FWA;
			if (to_eeprom) {
				flag |= Mwp.WPDL.SAVE_EEPROM;
			}
			callback = upload_mission.callback;
			Mwp.upload_mm(MissionManager.mdx, flag);
			yield;
			return MBus.nwpts;
		}

		public bool connection_status (out string device) throws GLib.Error {
			device = Mwp.dev_entry.text;
			return Mwp.msp.available;
		}

		public bool connect_device (string device) throws GLib.Error {
			int n = Mwp.append_combo(Mwp.dev_combox, device);
			if(n == -1)
				return false;
			Mwp.dev_combox.set_active(n);
			Msp.connect_serial();
			return Mwp.msp.available;
		}
	}
}