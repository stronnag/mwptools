namespace Gis {
	public Shumate.PathLayer svy_path;
	public Shumate.MarkerLayer svy_markers;
	public Shumate.PathLayer svy_mpath;
	public Shumate.MarkerLayer svy_mpoints;
}

namespace SMenu {
	MWPPoint mk;
}

internal class AsPop : Object {
  internal Gtk.PopoverMenu pop;
  internal Gtk.Button button;

  public AsPop (GLib.MenuModel mmodel, MWPPoint mk, int n) {
    pop = new Gtk.PopoverMenu.from_model(mmodel);
    pop.set_has_arrow(true);
    var plab = new Gtk.Label("Survey #%d".printf(mk.no+1));
    var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL,1);
    box.hexpand = true;
    plab.hexpand = true;
    box.append(plab);
    if(n == -1) {
      pop.set_autohide(false);
      button = new Gtk.Button.from_icon_name("window-close");
      button.halign = Gtk.Align.END;
      box.append(button);
    } else {
      pop.set_autohide(true);
    }
    pop.add_child(box, "label");
	SMenu.mk = mk;
    pop.set_parent(mk);
  }
}


namespace Survey {
	//	const string POINTCOL="#a0a0a0a0";
	const string POINTCOL="#ffcd70a0";
	const string SQRCOL="#ff0000a0";
	const string PATHCOL ="rgba(0xc5,0xc5,0xc5, 0.625)";
	const string FILLCOL ="rgba(0,0,0, 0.2)";
	const int POINTSZ=36;
	const int SQRSZ=20;

	[GtkTemplate (ui = "/org/stronnag/mwp/survey.ui")]
	public class Dialog : Adw.Window {
		[GtkChild]
		private unowned Gtk.DropDown as_type;
		[GtkChild]
		private unowned Gtk.Entry as_angle;
		[GtkChild]
		private unowned Gtk.DropDown as_turn;
		[GtkChild]
		private unowned Gtk.Entry as_rowsep;
		[GtkChild]
		private unowned Gtk.Entry as_altm;
		[GtkChild]
		private unowned Gtk.Switch as_rth;
		[GtkChild]
		private unowned Gtk.CheckButton as_amsl;
		[GtkChild]
		private unowned Gtk.Entry as_speed;
		[GtkChild]
		private unowned Gtk.Button as_apply;
		[GtkChild]
		private unowned Gtk.Button as_view;
		[GtkChild]
		private unowned Gtk.Button as_mission;
		[GtkChild]
		private unowned Gtk.Label as_npoints;
		[GtkChild]
		private unowned Gtk.Label as_dist;
		[GtkChild]
		private unowned Gtk.Label as_time;
		[GtkChild]
		private unowned Gtk.MenuButton button_menu;

		[GtkChild]
		private unowned Gtk.Grid pgrid;
		[GtkChild]
		private unowned Gtk.Grid sgrid;
		[GtkChild]
		private unowned Gtk.Entry ss_angle;
		[GtkChild]
		private unowned Gtk.Entry ss_dist;
		[GtkChild]
		private unowned Gtk.Entry ss_exp;

		private GLib.MenuModel as_menu;
		private GLib.MenuModel as_fmenu;

		internal GLib.SimpleActionGroup dg;
		internal GLib.SimpleActionGroup dg1;

		private uint genpts;

		private void init_result() {
			as_npoints.label = "0";
			as_dist.label = "0.0";
			as_time.label = "00:00";
		}

		public Dialog () {
			genpts = 0;
			transient_for = Mwp.window;

			as_angle.text="0";
			as_angle.activate.connect(() => {
					generate_path();
				});

			as_rowsep.text = "20";
			as_rowsep.activate.connect(() => {
					validate_bbox();
					generate_path();
				});

			as_turn.notify["selected"].connect(() =>  {
					generate_path();
				});

			as_altm.text = "50";
			as_speed.text = "7";

			ss_angle.text = "0";
			ss_angle.activate.connect(() => {
					generate_square();
				});

			ss_dist.text = "50";
			ss_dist.activate.connect(() => {
					generate_square();
				});

			ss_exp.text = "7";
			ss_exp.activate.connect(() => {
					generate_square();
				});

			as_mission.clicked.connect(() => {
					generate_mission();
				});

			as_view.clicked.connect(() => {
					reset_view();
					validate_bbox();
				});

			as_apply.clicked.connect(() => {
					if(as_type.selected == 0) {
						generate_path();
					} else {
						generate_square();
					}
				});

			as_type.notify["selected"].connect(() =>  {
					if(as_type.selected == 0) {
						sgrid.visible = false;
						pgrid.visible = true;
					} else {
						pgrid.visible = false;
						sgrid.visible = true;
					}
					ss_angle.sensitive =  (as_type.selected != 2);
					reset_view();
				});

			as_mission.sensitive = false;
			init_result();
			init();
			validate_bbox();
		}

		private void generate_mission() {
			int alt = int.parse(as_altm.text);
			double dtmp = DStr.strtod(as_speed.text, null);
			int lspeed = (int)(100*dtmp);
			if(as_type.selected == 0) {
				var rows = generate_path();
				Survey.build_mission(rows, alt, lspeed, as_rth.active, as_amsl.active);
			} else {
				var pts = Gis.svy_mpath.get_nodes();
				var npts = pts.length();
				AreaCalc.Vec []vec= new AreaCalc.Vec [npts];
				for(var j = 0; j < npts; j++) {
					var mk = (MWPPoint)pts.nth_data(j);
					AreaCalc.Vec v= AreaCalc.Vec(){y = mk.latitude, x = mk.longitude};
					vec[j] = v;
				}
				Survey.build_square_mission(vec, alt, lspeed, as_rth.active, as_amsl.active);
			}
			close();
		}

		private MapUtils.BoundingBox validate_bbox() {
			MapUtils.BoundingBox b={999.0, 999.0, -999.0, -999.0};
			if(as_type.selected == 0) {
				var pts = Gis.svy_path.get_nodes();
				var npts = pts.length();
				for(var j = 0; j < npts; j++) {
					var mk = (MWPPoint)pts.nth_data(j);
					if(mk.latitude < b.minlat) {
						b.minlat = mk.latitude;
					}
					if(mk.latitude > b.maxlat) {
						b.maxlat = mk.latitude;
					}
					if(mk.longitude < b.minlon) {
						b.minlon = mk.longitude;
					}
					if(mk.longitude > b.maxlon) {
						b.maxlon = mk.longitude;
					}
				}
				double width = 0;
				double height = 0;
				b.get_map_size(out width, out height);
				var rs = DStr.strtod(as_rowsep.text,null);
				var wpts = (int)(width / rs);
				var hpts = (int)(height / rs);
				if(as_type.selected == 0) {
					as_apply.sensitive = (wpts < 400 && hpts < 400);
				}
			}
			return b;
		}

		private void reset_view(bool default = true) {
			genpts = 0;
			as_mission.sensitive = false;
			Gis.svy_mpoints.remove_all();
			Gis.svy_markers.remove_all();
			Gis.svy_mpath.remove_all();
			Gis.svy_path.remove_all();
			if(default) {
				if(as_type.selected == 0) {
					make_default_box();
				} else {
					init_square();
				}
			}
			init_result();
		}

		private void init_square() {
			double clat, clon;
			MapUtils.get_centre_location(out clat, out clon);
			var mk = new MWPPoint.with_colour("#00ffff60");
			mk.set_size_request(POINTSZ, POINTSZ);
			mk.latitude = clat;
			mk.longitude = clon;
			mk.no = 0;
			mk.set_draggable(true);
			Gis.svy_mpoints.add_marker(mk);
			Gis.svy_mpath.add_node(mk);
			as_apply.sensitive = true;
		}

		private void generate_survey(AreaCalc.RowPoints[] rows, double speed ) {
			var col = "#00ffff60";
			MWPLabel mk = null;
			int n = 0;
			foreach (var r in rows){
				n++;
				mk = new MWPLabel("%3d".printf(n));
				mk.latitude = r.start.y;
				mk.longitude = r.start.x;
				mk.set_colour(col);
				Gis.svy_mpath.add_node(mk);
				Gis.svy_mpoints.add_marker(mk);
				n++;
				mk = new MWPLabel("%3d".printf(n));
				mk.latitude = r.end.y;
				mk.longitude = r.end.x;
				mk.set_colour(col);
				Gis.svy_mpath.add_node(mk);
				Gis.svy_mpoints.add_marker(mk);
			}

			if(as_rth.active) {
				mk.set_colour("#00aaff60");
			}
			genpts = rows.length;

			set_summary(speed);
		}

		private void set_summary(double speed) {
			var pts = Gis.svy_mpath.get_nodes();
			var npts = pts.length();
			as_mission.sensitive = (((int)as_rth.sensitive + npts) < 121);
			as_npoints.label = npts.to_string();

			var td  = 0.0;
			double llat = 0;
			double llon = 0;
			for(var j = 0; j < npts; j++) {
				var mk = (MWPMarker)pts.nth_data(j);
				if(j != 0) {
					double _c,d;
					Geo.csedist(llat, llon, mk.latitude, mk.longitude, out d, out _c);
					td += d;
				}
				llat = mk.latitude;
				llon = mk.longitude;
			}
			td *= 1852.0;
			as_dist.label = "%.1fm".printf(td);
			if (speed > 0) {
				var et = (int)(td/speed + 0.5);
				var em = et / 60;
				var es = et % 60;
				as_time.label = "%02d:%02d".printf(em, es);
			}
		}

		private AreaCalc.RowPoints[]  generate_path() {
			var pts = Gis.svy_path.get_nodes();
			var npts = pts.length();
			AreaCalc.Vec []vec= new AreaCalc.Vec [npts];

			init_result();

			if(!as_apply.sensitive || npts < 3) {
				genpts = 0;
				as_mission.sensitive = false;
				return {};
			} else {
				Gis.svy_mpath.remove_all();
				Gis.svy_mpoints.remove_all();
				for(var j = 0; j < npts; j++) {
					var mk = (MWPPoint)pts.nth_data(j);
					AreaCalc.Vec v= AreaCalc.Vec(){y = mk.latitude, x = mk.longitude};
					vec[j] = v;
				}
				double angle = DStr.strtod(as_angle.text,null);
				double separation = DStr.strtod(as_rowsep.text,null);
				uint8 turn = (uint8)as_turn.selected;
				double speed = DStr.strtod(as_speed.text, null);
				var rows = AreaCalc.generateFlightPath(vec, angle, turn, separation);
				generate_survey(rows, speed);
				return rows;
			}
		}

		private void  generate_square() {
			var col = "#00ffff60";
			var pts = Gis.svy_mpath.get_nodes();
			var mk = (MWPPoint)pts.nth_data(0);
			double plat = mk.latitude;
			double plon = mk.longitude;
			reset_view();
			pts = Gis.svy_mpath.get_nodes();
			mk = (MWPPoint)pts.nth_data(0);
			mk.latitude = plat;
			mk.longitude = plon;
			mk.set_draggable(false);
			var dist = DStr.strtod(ss_dist.text, null);
			var iangle = int.parse(ss_angle.text);
			var nexp = int.parse(ss_exp.text);
			double edist = 0;
			double speed = DStr.strtod(as_speed.text, null);

			if(as_type.selected == 1) {
				for(var j = 0; j < 4* nexp; j++) {
					if((j & 1) == 0) {
						edist += dist;
					}
					Geo.posit(plat, plon, iangle, edist/1852.0, out plat, out plon);
					mk = new MWPPoint.with_colour(col);
					mk.set_size_request(SQRSZ, SQRSZ);
					mk.latitude = plat;
					mk.longitude = plon;
					mk.no = j+1;
					Gis.svy_mpoints.add_marker(mk);
					Gis.svy_mpath.add_node(mk);
					iangle += 90;
					iangle %= 360;
					genpts++;
				}
			} else {
				double alat, alon;
				int n = 0;
				int last = 360 * nexp + 180 + 10;
				for(var j = 180; j < last;  ) {
					var r = (dist/360.0) * (double)(j);
					var ang = j % 360;
					n++;
					Geo.posit(plat, plon, ang, r/1852.0, out alat, out alon);
					mk = new MWPPoint.with_colour(col);
					mk.set_size_request(SQRSZ, SQRSZ);
					mk.latitude = alat;
					mk.longitude = alon;
					mk.no = n;
					Gis.svy_mpoints.add_marker(mk);
					Gis.svy_mpath.add_node(mk);
					genpts++;
					var delta = j * 30 /(last-190);
					// angle will start 45° down to 15° (initial 180 => +2)
					j += (47-delta);
				}
			}
			set_summary(speed);
		}

		private MWPPoint SurveyMk(int n, double plat, double plon, int ipt=-1) {
			var mk = new MWPPoint.with_colour(POINTCOL);
			mk.latitude = plat;
			mk.longitude = plon;
			mk.no = n;
			mk.set_size_request(POINTSZ, POINTSZ);
			mk.set_draggable(true);
			mk.popup_request.connect((n, x, y) => {
					var pop = new AsPop(as_menu, mk, n);
					if (n == -1) {
						pop.button.clicked.connect(() => {
								pop.pop.popdown();
							});
					}
					pop.pop.popup();
				});
			Gis.svy_markers.add_marker(mk);
			if(ipt == -1) {
				Gis.svy_path.add_node(mk);
			} else {
				Gis.svy_path.insert_node (mk, (uint)ipt);
			}
			mk.drag_motion.connect((la,lo) => {
					validate_bbox();
					if(genpts != 0) {
						generate_path();
					}
				});
			return mk;
		}

		public uint renumber() {
			var npts = Gis.svy_path.get_nodes().length();
			for(var j = 0; j < npts; j++) {
				var mk = (MWPPoint)Gis.svy_path.get_nodes().nth_data(j);
				mk.no = j;
			}
			return npts;
		}

		public void cleanup() {
			Gis.svy_mpoints.remove_all();
			Gis.svy_markers.remove_all();
			Gis.svy_mpath.remove_all();
			Gis.svy_path.remove_all();
			Gis.map.remove_layer(Gis.svy_mpoints);
			Gis.map.remove_layer(Gis.svy_mpath);
			Gis.map.remove_layer(Gis.svy_markers);
			Gis.map.remove_layer(Gis.svy_path);
		}

		public void load_file() {
			IChooser.Filter []ifm = {
				{"Text file", {"txt"}},
			};
			var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
			fc.title = "Open Area File";
			fc.modal = true;
			fc.open.begin (Mwp.window, null, (o,r) => {
					try {
						var file = fc.open.end(r);
						var fn = file.get_path ();
						var pts = parse_file(fn);
						if(pts.length > 0) {
							reset_view(false);
							int n = 0;
							foreach(var p in pts) {
								SurveyMk(n, p.y, p.x);
								n++;
							}
							var bb = validate_bbox();
							double clat= bb.get_centre_latitude();
							double clon= bb.get_centre_longitude();
							MapUtils.map_centre_on(clat, clon);
							var z = MapUtils.evince_zoom(bb);
							Gis.map.viewport.set_zoom_level(z);
						}
					} catch (Error e) {
						MWPLog.message("Failed to open mission file: %s\n", e.message);
					}
				});
		}

		public void save_file() {
			IChooser.Filter []ifm = {
				{"Text file", {"txt"}},
			};
			var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
			fc.title = "Save Area File";
			fc.modal = true;
			fc.save.begin (Mwp.window, null, (o,r) => {
					try {
						var fh = fc.save.end(r);
						var fn = fh.get_path ();
						var pts = get_points();
						Survey.write_file(fn, pts);
					} catch (Error e) {
						MWPLog.message("Failed to save mission file: %s\n", e.message);
					}
				});
		}

		private AreaCalc.Vec[] get_points() {
			var pts = Gis.svy_path.get_nodes();
			var npts = pts.length();
			AreaCalc.Vec[] vpts = {};
			for(var j = 0; j < npts; j++) {
				var mk = (MWPPoint)pts.nth_data(j);
				var  v = AreaCalc.Vec(){y = mk.latitude, x = mk.longitude};
				vpts += v;
			}
			return vpts;
		}

		public void init() {
			var sbuilder = new Gtk.Builder.from_resource ("/org/stronnag/mwp/surveymenu.ui");
			as_menu = sbuilder.get_object("as_popup") as GLib.MenuModel;
			as_fmenu = sbuilder.get_object("as_menu") as GLib.MenuModel;
			dg = new GLib.SimpleActionGroup();
			dg1 = new GLib.SimpleActionGroup();

			var aq = new GLib.SimpleAction("asinsert",null);
			aq.activate.connect(() => {
					var npts = Gis.svy_path.get_nodes().length();
					var np = (1+SMenu.mk.no) % npts;
					var popmk = (MWPPoint)Gis.svy_path.get_nodes().nth_data(np);
					var nlat = (SMenu.mk.latitude + popmk.latitude)/2;
					var nlon = (SMenu.mk.longitude + popmk.longitude)/2;
					uint npx = npts - (SMenu.mk.no+1);
					SurveyMk((int)npts, nlat, nlon, (int)npx);
					var nv = renumber();
					if  (nv > 3) {
						MwpMenu.set_menu_state(dg, "asdelete", true);
					}
					validate_bbox();
					if(genpts != 0) {
						generate_path();
					}
				});
			dg.add_action(aq);

			aq = new GLib.SimpleAction("asdelete",null);
			aq.activate.connect(() => {
					Gis.svy_path.remove_node(SMenu.mk);
					Gis.svy_markers.remove_marker(SMenu.mk);
					var nv = renumber();
					if  (nv < 4) {
						MwpMenu.set_menu_state(dg, "asdelete", false);
					}
					validate_bbox();
					if(genpts != 0) {
						generate_path();
					}
				});
			dg.add_action(aq);

			button_menu.menu_model = as_fmenu;
			button_menu.always_show_arrow = false;
			var popover = button_menu.popover as Gtk.PopoverMenu;
			popover.has_arrow = false;
			popover.flags = Gtk.PopoverMenuFlags.NESTED;

			aq = new GLib.SimpleAction("asload",null);
			aq.activate.connect(() => {
					load_file();
				});
			dg1.add_action(aq);

			aq = new GLib.SimpleAction("assave",null);
			aq.activate.connect(() => {
					save_file();
				});
			dg1.add_action(aq);

			Mwp.window.insert_action_group("survey", dg);
			this.insert_action_group("asfiles", dg1);

			Gis.svy_path = new Shumate.PathLayer(Gis.map.viewport);
			Gis.svy_mpath = new Shumate.PathLayer(Gis.map.viewport);
			Gis.svy_markers = new Shumate.MarkerLayer(Gis.map.viewport);
			Gis.svy_mpoints = new Shumate.MarkerLayer(Gis.map.viewport);

			Gdk.RGBA rgba={};
			rgba.parse(PATHCOL);
			Gis.svy_path.set_stroke_width(5.0);
			Gis.svy_path.set_stroke_color(rgba);
			Gis.map.add_layer(Gis.svy_path);
			Gis.svy_path.closed = true;
			rgba.parse(FILLCOL);
			Gis.svy_path.set_fill_color(rgba);
			Gis.svy_path.fill = true;

			rgba = {1,0,0,0.7f};
			Gis.svy_mpath.set_stroke_width(2.0);
			Gis.svy_mpath.set_stroke_color(rgba);
			Gis.map.add_layer(Gis.svy_mpath);
			Gis.map.add_layer(Gis.svy_mpoints);
			Gis.map.add_layer(Gis.svy_markers);
			make_default_box();
		}

		public void make_default_box() {
			var bbox = MapUtils.get_bounding_box();
			var wlon = 0.1*(bbox.maxlon - bbox.minlon);
			var wlat = 0.1*(bbox.maxlat - bbox.minlat);

			var plat = bbox.maxlat - wlat;

			var plon = bbox.minlon + wlon;
			SurveyMk(0, plat, plon);

			plon = bbox.maxlon - wlon;
			SurveyMk(1, plat, plon);

			plat = bbox.minlat + wlat;
			SurveyMk(2, plat, plon);

			plon = bbox.minlon + wlon;
			SurveyMk(3, plat, plon);
		}
	}
}