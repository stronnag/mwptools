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

using Gtk;
namespace Follow {
	Window fmdlg;
	FPoint fmpt;
	double flat;
	double flon;
	bool _use_gpsd = false;

	public void init() {
		fmdlg = new Window();
		fmpt = new FPoint();
		fmpt.fmpoint.latitude = flat;
		fmpt.fmpoint.longitude = flon;
		fmpt.fmpt_move.connect((la, lo) => {
				double dist=0,cse=0;
				Geo.csedist(Mwp.xlat, Mwp.xlon, la, lo, out dist, out cse);
				StringBuilder sb = new StringBuilder();
				sb.append_printf("<span font='monospace'>%s</span>", PosFormat.pos(la, lo, Mwp.conf.dms));
				if(dist < 10.0) {
					sb.append_printf("<span font='monospace'> (%.0fm,%0.f°)</span>", dist*1852, cse);
				}
                fmdlg.set_label(sb.str);
			});

		fmdlg.close_request.connect(() => {
				if(!_use_gpsd){
					fmpt = null;
				}
				return false;
			});

		validate_fm();
		fmpt.show_followme(true);
		fmdlg.present();
		fmdlg.ready.connect((s,a) => {
				switch(s) {
				case 1:
				fmpt.show_followme(!FPoint.is_visible);
				if (FPoint.is_visible) {
					validate_fm();
				}
				break;
				case 2:
				followme_set_wp(flat, flon, a); // send to vehicle
				break;
				default:
				break;
				}
			});
	}

	private void validate_fm() {
		var bbox = MapUtils.get_bounding_box();
		if (!bbox.covers(flat, flon)) {
			MapUtils.get_centre_location(out flat, out flon);
			fmpt.set_followme(flat, flon);
		}
	}

	public void run () {
		init();
		if (!fmpt.has_location()) {
			MapUtils.get_centre_location(out flat, out flon);
			fmpt.set_followme(flat, flon);
		}
		fmpt.show_followme(true);
	}

	private void followme_set_wp(double lat, double lon, int alt) {
		uint8 buf[32];
		double dist=0,cse = 0;
			Geo.csedist(Mwp.xlat, Mwp.xlon, lat, lon, out dist, out cse);
			//			MWPLog.message(":DBG: Follow Me: Set lat=%.6f lon=%.6f %.0fm %.0f°\n", lat, lon, dist*1852.0, cse);
			MSP_WP [] wps={};
			MSP_WP wp = MSP_WP();
			wp.wp_no = 255;
			wp.action =  Msp.Action.WAYPOINT;
			wp.lat = (int32)(lat*1e7);
			wp.lon = (int32)(lon*1e7);
			wp.altitude = 100*(int32)alt;
			wp.p1 = (int16)cse; // heading
			wp.p2 = wp.p3 = 0;
			wp.flag = 0xa5;
			wps += wp;
			Mwp.wpmgr.npts = (uint8)wps.length;
			Mwp.wpmgr.wpidx = 0;
			Mwp.wpmgr.wps = wps;
			Mwp.wpmgr.wp_flag = Mwp.WPDL.FOLLOW_ME;
			var nb = Mwp.serialise_wp(wp, buf);
			Mwp.queue_cmd(Msp.Cmds.SET_WP, buf, nb);
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/fm-dialog.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		internal unowned  Gtk.SpinButton fm_spin_alt;
		[GtkChild]
		internal unowned  Gtk.Label fm_label;
		[GtkChild]
		public unowned  Gtk.Button fm_ok;
		[GtkChild]
		public unowned  Gtk.Button fm_toggle;
		[GtkChild]
		public unowned  Gtk.CheckButton use_gpsd;

		public signal void ready(int state, int alt);

		public Window() {
			use_gpsd.active = _use_gpsd;
			set_transient_for(Mwp.window);
			fm_toggle.clicked.connect (() => {
					ready(1,0);
				});

			fm_ok.clicked.connect (() => {
					int altval = (int)fm_spin_alt.adjustment.value;
					ready(2, altval);
				});

			use_gpsd.toggled.connect(() => {
					_use_gpsd = use_gpsd.active;
				});

			Gpsd.reader.gpsd_result.connect((s) => {
					if(s != null && s.contains("TPV")) {
						if(use_gpsd.active) {
							var d = Gpsd.parse(s);
							if ((d.mask & (Gpsd.Mask.TIME|Gpsd.Mask.LAT|Gpsd.Mask.LON)) != 0 && d.fix == 3) {
								int altval = (int)fm_spin_alt.adjustment.value;
								if(fmpt != null) {
									fmpt.set_followme(d.lat, d.lon);
								}
								followme_set_wp(d.lat, d.lon, altval);
							}
						}
					}
				});
		}

		public void set_label(string ltext) {
			fm_label.label = ltext;
		}
	}

	public class FPoint : GLib.Object {
		public static bool is_visible = false;
		public static bool has_loc = false;

		public signal void fmpt_move(double lat, double lon);
		internal const string GREEN = "#4cc010a0";
		internal Shumate.MarkerLayer fmlayer;
		internal MWPLabel fmpoint;

		public FPoint() {
			fmlayer = new Shumate.MarkerLayer(Gis.map.viewport);
			fmpoint = new MWPLabel("⨁");
			var fs = MwpScreen.rescale(1.25);
			fmpoint.set_font_scale(fs);
			fmpoint.set_colour (GREEN);
			fmpoint.set_text_colour("white");
			fmpoint.set_draggable(true);
			fmpoint.drag_motion.connect((dx,dy) => {
					flat = fmpoint.get_latitude();
					flon = fmpoint.get_longitude();
					fmpt_move(flat, flon);
				});
			Gis.map.insert_layer_above (fmlayer, Gis.hm_layer);
			fmlayer.add_marker(fmpoint);
		}

		~FPoint() {
			fmlayer.remove_marker(fmpoint);
			Gis.map.remove_layer(fmlayer);
			fmlayer = null;
		}

		public void show_followme(bool state) {
			if(state) {
				fmpoint.visible = true;
			} else {
				fmpoint.visible = false;
			}
			is_visible = state;
		}

		public void set_followme(double lat, double lon) {
			has_loc = true;
			fmpoint.set_location (lat, lon);
			flat = lat;
			flon = lon;
			fmpt_move(flat, flon);
		}

		public void get_followme(out double lat, out double lon) {
			lat = flat;
			lon = flon;
		}

		public bool has_location() {
			return has_loc;
		}

		public void reset() {
			if(!is_visible) {
				has_loc = false;
				flat = 0.0;
				flon = 0.0;
			}
		}
	}
}
