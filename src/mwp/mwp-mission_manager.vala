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

namespace MT {
	GLib.MenuModel wppopmenu;
	unowned Mission _m;
	unowned MWPLabel _mk;
	int mtno;
}

namespace MissionManager {
	public const uint MAXMULTI = 9;
	public uint wp_max = 120;
	public int mdx = -1; // current mission segment
	public Mission []msx;
	public string last_file = null;
	public GLib.SimpleActionGroup dg;
	public ulong acthdlr;
	private TA.Dialog tadialog;
	bool is_dirty;
	Previewer pv;

	public void init() {
		tadialog = new TA.Dialog();
		msx={};
		is_dirty = false;
		add_wp_actions();
		wp_max = Mwp.conf.max_wps;
		acthdlr = Mwp.window.actmission.notify["selected"].connect(() => {
				var mi = Mwp.window.actmission.get_selected_item() as StrIntItem;
				if (mi != null) {
					if (mi.id != -1) {
						msx[mdx].update_meta();
						MsnTools.clear_display();
						mdx = mi.id;
						visualise_mission();
						msx[mdx].changed();
					} else {
						if (mdx < MAXMULTI) {
							msx[mdx].update_meta();
							MsnTools.clear_display();
							mdx = msx.length;
							msx.resize((int)mdx+1);
							msx[mdx] = new Mission();
							update_mission_combo();
							msx[mdx].changed();
						}
					}
				}
			});
		update_mission_combo();
	}

	public void append_mission_file() {
		IChooser.Filter []ifm = {
			{"Mission XML", {"mission"}},
			{"Mission JSON", {"json"}},
		};

		var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
		fc.title = "Append Mission File";
		fc.modal = true;
		fc.open.begin (Mwp.window, null, (o,r) => {
				try {
					var file = fc.open.end(r);
					var fn = file.get_path ();
					open_mission_file(fn, true);
				} catch (Error e) {
					MWPLog.message("Failed to open mission file: %s\n", e.message);
				}
			});
	}

	public void load_mission_file() {
		IChooser.Filter []ifm = {
			{"Mission XML", {"mission"}},
			{"Mission JSON", {"json"}},
		};

		var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
		fc.title = "Open Mission File";
		fc.modal = true;
		fc.open.begin (Mwp.window, null, (o,r) => {
				try {
					var file = fc.open.end(r);
					var fn = file.get_path ();
					open_mission_file(fn, false);
				} catch (Error e) {
					MWPLog.message("Failed to open mission file: %s\n", e.message);
				}
			});
	}

	private uint check_mission_length(Mission [] xmsx) {
		uint nwp = 0;
		foreach(var m in xmsx) {
			nwp += m.npoints;
		}
		if (nwp == 1 && xmsx[0].points[0].action == Msp.Action.RTH
			&& xmsx[0].points[0].flag == 165) {
			nwp = 0;
		}
		return nwp;
	}

	public Gtk.FileDialog setup_save_mission_file_as() {
		IChooser.Filter []ifm = {
			{"Mission XML", {"mission"}},
			{"Mission JSON", {"json"}},
		};
		var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
		fc.title = "Save Mission File";
		fc.modal = true;
		return fc;
	}

	public void save_mission_file_as() {
		var fc = setup_save_mission_file_as();
		fc.save.begin (Mwp.window, null, (o,r) => {
				try {
					var fh = fc.save.end(r);
					var fn = fh.get_path ();
					last_file = fn;
					write_mission_file(last_file, 0);
				} catch (Error e) {
					MWPLog.message("Failed to save mission file: %s\n", e.message);
				}
			});
	}

	public void save_mission_file() {
		if(last_file != null) {
			write_mission_file(last_file, 0);
		} else {
			save_mission_file_as();
		}
		is_dirty = false;
	}

	public Mission? open_mission_file(string fn, bool append=false) {
		bool is_j = fn.has_suffix(".json");
		bool is_x = fn.has_suffix(".mission");
		last_file = null;
		Mission?[]_msx=null;
		if (is_j) {
			_msx = JsonIO.read_json_file(fn);
		} else if (is_x) {
			_msx = XmlIO.read_xml_file (fn, true);
		} else {
			_msx = TxtIO.read_txt(fn);
			last_file = null;
		}
		if (_msx == null)
			return null;

		mdx = 0;
		var nwp = check_mission_length(_msx);
		if (nwp == 0)
			return null;

		int imdx = 0;
		if (append) {
			imdx = _msx.length;
			mdx = imdx;
			var mlim = msx.length;
			imdx += mlim;
			msx.resize((int)imdx);
			foreach(var m in _msx) {
				msx[mlim] = m;
				mlim++;
			}
			if (mlim > MAXMULTI) {
				Mwp.add_toast_text("Mission set count (%d) exceeds firmware maximum of 9.\nYou will not be able to download the whole set to the FC".printf(mlim));
			}
		} else {
			msx = _msx;
			//lastmission = msx_clone();
		}

		if (nwp > wp_max) {
			Mwp.add_toast_text("Total number of WP (%u) exceeds firmware maximum (%u).\nYou will not be able to download the whole set to the FC".printf(nwp,wp_max));
		}
		var _ms = setup_mission_from_mm();
		if (_ms == null) {
			Mwp.add_toast_text("Failed to load %s".printf(fn));
		} else {
			last_file = fn;
			is_dirty = append;
		}
		return _ms;
	}

	public Mission? setup_mission_from_mm() {
		Mission? _ms = null;
		if (msx.length > 0) {
			uint mnp = 0;
			for(var k = 0; k < msx.length; k++) {
				var m = msx[k];
				if(m.homey == 0 && m.homex == 0) {
					int ngp = 0;
					foreach(var mi in m.points) {
						if (mi.is_geo()) {
							ngp++;
							m.homey += mi.lat;
							m.homex += mi.lon;
						}
					}
					m.homey /= ngp;
					m.homex /= ngp;
				}
				for(var i = 0; i < m.npoints; i++) {
					if (m.points[i].flag == 0x48) {
						m.points[i].lat = m.homey;
						m.points[i].lon = m.homex;
					}
				}
				if(Rebase.has_reloc()) {
					for(var j = 0; j < msx.length; j++) {
						rewrite_mission(ref msx[j]);
					}
				}
				mnp += m.npoints;
			}
			_ms = msx[mdx];
			Mwp.add_toast_text("Loaded mission file with %u/%u points (%u segments)".printf(_ms.npoints, mnp, msx.length));
			foreach(var _m in msx) {
				_m.calc_mission_distance();
			}
			update_mission_combo();
			MsnTools.clear_display();
			visualise_mission();
		}
		return _ms;
	}

	public void visualise_mission() {
		zoom_to_mission();
		HomePoint.hp.opacity = 1.0;
		MsnTools.draw_mission(msx[mdx]);
	}

	public void zoom_to_mission() {
		var _ms = current();
		if (_ms != null) {
			if(_ms.cx != 0 && _ms.cy != 0) {
				Gis.map.center_on(_ms.cy, _ms.cx);
			} else {
				Gis.map.center_on(_ms.homey, _ms.homex);
			}
			if(_ms.zoom > 0) {
				Mwp.set_zoom_sanely(_ms.zoom);
			}
			HomePoint.set_home(_ms.homey, _ms.homex);
		} else {
			Mwp.add_toast_text("No loaded mission");
		}
	}

	public void check_mm_list() {
		// FIXME not sure this is the correct solution
		/*
		if(!Mwp.window.wpeditbutton.active) {
			bool havez = false;
			for(var i = 0; i < msx.length; i++) {
				if(msx[i].points.length == 0)
					havez = true;
			}
			if(havez) {
				Mission []nmsx={};
				for(var i = 0; i < msx.length; i++) {
					if(msx[i].points.length > 0) {
						nmsx += msx[i];
					}
				}
				msx = nmsx;
				if (msx.length == 0) {
					update_mission_combo();
					HomePoint.try_hide();
				}
			}
		}
		*/
	}

	public void update_mission_combo() {
		// Don't fire signal handler while updating
		GLib.SignalHandler.block(Mwp.window.actmission, acthdlr);
		StrIntItem []menu={};
		int j = 0;
		for(; j < msx.length; j++) {
			menu += new StrIntItem((j+1).to_string(), j);
		}
		if (j < MissionManager.MAXMULTI) {
			if (j == 0) {
				menu += new StrIntItem("(none)", -1);
			} else {
				menu += new StrIntItem("New", -1);
			}
		} else {
			MWPLog.message("MM size exceeded\n");
		}
		var imdx = mdx;
		var clen = Mwp.amis.model.get_n_items();
		Mwp.amis.model.splice(0, clen, menu);
		if(imdx == -1)
			imdx = 0;
		Mwp.window.actmission.set_selected(imdx);
		GLib.SignalHandler.unblock(Mwp.window.actmission, acthdlr);
		Mwp.window.actmission.sensitive = (menu.length > 1);
	}

	public void insert_new (double lat, double lon) {
		Mission? m;
		if(mdx == -1) {
			mdx = 0;
			msx.resize(mdx+1);
			msx[0] = new Mission();
			update_mission_combo();
			msx[0].homey = HomePoint.hp.latitude;
			msx[0].homex = HomePoint.hp.longitude;
		}
		m = msx[mdx];
		MsnTools.insert_new(m, lat, lon);
	}

	private void rewrite_mission(ref Mission m) {
		if (Rebase.has_reloc()) {
			if (m.homex != 0 && m.homey != 0) {
				Rebase.set_origin(m.homey, m.homex);
			}
			m.homey = Rebase.reloc.lat;
			m.homex = Rebase.reloc.lon;
		}
		for(var i = 0; i < m.npoints; i++) {
			if (m.points[i].is_geo()) {
				if(!Rebase.is_valid()) {
					MWPLog.message("WARNING: No home for relocated mission, using WP %d\n",
								   m.points[i].no);
					Rebase.set_origin(m.points[i].lat, m.points[i].lon);
				}
				var _lat = m.points[i].lat;
				var _lon = m.points[i].lon;
				Rebase.relocate(ref _lat, ref _lon);
				m.points[i].lat = _lat;
				m.points[i].lon = _lon;
			}
		}
		if (Rebase.is_valid()) {
			Rebase.relocate(ref m.cy, ref m.cx);
		}
	}

	public void write_mission_file(string fn, uint mask=0) {
		StringBuilder sb;
		uint8 ftype=0;

		if(fn.has_suffix(".mission") || fn.has_suffix(".xml"))
			ftype = 'm';

		if(fn.has_suffix(".json")) {
			ftype = 'j';
		}

		if(ftype == 0) {
			sb = new StringBuilder(fn);
			ftype = 'm';
			sb.append(".mission");
			fn = sb.str;
		}
		foreach (var ms in msx) {
			ms.update_meta();
			ms.zoom = (uint)Gis.map.viewport.zoom_level;
		}

		if (ftype == 'm') {
			XmlIO.to_xml_file(fn, msx);
		} else {
			JsonIO.to_json_file(fn, msx);
		}
	}

	public Mission? current() {
		if (mdx != -1) {
			return msx[mdx];
		}
		return null;
	}

	private void add_wp_actions() {
		var sbuilder = new Gtk.Builder.from_resource ("/org/stronnag/mwp/wppop.ui");
		MT.wppopmenu = sbuilder.get_object("wp-pop-menu") as GLib.MenuModel;

		GLib.SimpleAction saq;

		saq = new GLib.SimpleAction("mclear",null);
		saq.activate.connect(() =>	{
				MsnTools.clear(MT._m);
			});
		Mwp.window.add_action(saq);

		saq = new GLib.SimpleAction("mtote",null);
		saq.activate.connect(() =>	{
				MissionManager.show_tote();
			});
		Mwp.window.add_action(saq);

		saq = new GLib.SimpleAction("mlosa",null);
		saq.activate.connect(() =>	{
				los_analysis(MT._mk.no);
			});
		Mwp.window.add_action(saq);

		saq = new GLib.SimpleAction("mta",null);
		saq.activate.connect(() =>	{
				tadialog.run();
			});
		Mwp.window.add_action(saq);

		saq = new GLib.SimpleAction("mpreview",null);
		saq.activate.connect(() =>	{
				pv = new Previewer();
				pv.run();
			});
		Mwp.window.add_action(saq);
		saq = new GLib.SimpleAction("mxpreview",null);
		saq.activate.connect(() =>	{
				pv.quit();
			});
		Mwp.window.add_action(saq);

		saq = new GLib.SimpleAction("wedit",null);
		saq.activate.connect(() =>	{
				EditWP.editwp(MT._mk.no);
			});
		Mwp.window.add_action(saq);

		saq = new GLib.SimpleAction("wdelete",null);
		saq.activate.connect(() =>	{
				MsnTools.delete(MT._m, MT._mk.no);
			});

		Mwp.window.add_action(saq);
		saq = new GLib.SimpleAction("wmove-after",null);
		saq.activate.connect(() =>	{
				MsnTools.move_after(MT._m, MT._mk.no);
			});
		Mwp.window.add_action(saq);
		saq = new GLib.SimpleAction("wmove-before",null);
		saq.activate.connect(() =>	{
				MsnTools.move_before(MT._m, MT._mk.no);
			});

		Mwp.window.add_action(saq);
		saq = new GLib.SimpleAction("winsert-before",null);
		saq.activate.connect(() =>	{
				MsnTools.insert_before(MT._m, MT._mk.no);
			});
		Mwp.window.add_action(saq);
		saq = new GLib.SimpleAction("winsert-after",null);
		saq.activate.connect(() =>	{
				MsnTools.insert_after(MT._m, MT._mk.no);
			});
		Mwp.window.add_action(saq);
		MwpMenu.set_menu_state(Mwp.window, "mxpreview", false);
	}

	private void los_analysis(int no) {
		var ms = MissionManager.current();
		validate_elevations(ms);
		var losa = new LOSSlider(Mwp.conf.los_margin);
		if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.LOSANA) != Mwp.DEBUG_FLAGS.NONE) {
			losa.set_log(true);
		}
		losa.new_margin.connect((m) => {
				Mwp.conf.los_margin = m;
			});
		losa.run(ms, no, false);
	}

	public bool validate_elevations(Mission ms) {
		bool res = true; // forever the optimist ...
		string? reason = null;

		if (DemManager.lookup(ms.homey, ms.homex) == Hgt.NODATA) {
			res = false;
		}

		if (res) {
			foreach (MissionItem m in ms.points) {
				if(m.is_geo()) {
					if (DemManager.lookup(m.lat, m.lon) == Hgt.NODATA) {
						reason = "WP%d".printf(m.no);
						res = false;
						break;
					}
				}
			}
		} else {
			reason = "mission home";
		}

		if (!res) {
			MWPLog.message("Don't seem to have all elevations (%s); this may end badly ..\n", reason);
		}
		return res;
	}
}
