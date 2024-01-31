using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public class GZEdit :Gtk.Window {
	private Gtk.Label zidx;
	private Gtk.ComboBoxText zshape;
	private Gtk.ComboBoxText ztype;
	private Gtk.ComboBoxText zaction;
	private Gtk.Entry zminalt;
	private Gtk.Entry zmaxalt;
	private Gtk.Entry zradius;
	private Gtk.Button[] buttons;
	private uint nitem;
	private int popid;
	private int popno;
	private Champlain.Label? mk;
	private Overlay? ovl;
	private GeoZoneManager gzmgr;
	private Gtk.Label lradius;
	private Gtk.Grid grid;
	private Gtk.Label newlab;
    private Gtk.Menu pop_menu;
	private double llat=0;
	private double llon=0;
	private Champlain.View view;
	private Gtk.MenuItem ditem;
	private unowned Champlain.Label? popmk;
	enum Buttons {
		ADD,
		PREV,
		NEXT,
		REMOVE,
		REFRESH
	}

	enum Upd {
		TYPE = 1,
		ACTION = 2,
		RADIUS = 0x10,
		MINALT = 0x20,
		MAXALT = 0x40,
		PROPERTIES = 0xf,
		ANY = 0xff,
	}


	public GZEdit(Gtk.Window? _w=null, GeoZoneManager _gzr, Champlain.View _v) {
		gzmgr = _gzr;
		view = _v;
		popid = -1;
		title = "mwp GeoZone Editor";
		window_position = Gtk.WindowPosition.CENTER;
		this.delete_event.connect (() => {
				refresh_storage(Upd.ANY, false);
				remove_edit_markers();
				return hide_on_delete();
			});

		buttons = {
			new Gtk.Button.from_icon_name ("list-add"),
			new Gtk.Button.from_icon_name ("go-previous"),
			new Gtk.Button.from_icon_name ("go-next"),
			new Gtk.Button.from_icon_name ("list-remove"),
			new Gtk.Button.from_icon_name ("view-refresh"),
		};

		newlab = new Gtk.Label(null);

		Gtk.ButtonBox bbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		bbox.set_layout (Gtk.ButtonBoxStyle.START);

		bbox.set_spacing (5);
		foreach (unowned var button in buttons) {
			bbox.add (button);
		}

		var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
		vbox.pack_start (bbox, false, false, 2);
		grid = new Gtk.Grid ();

		zidx = new Gtk.Label("-");

		zshape = new Gtk.ComboBoxText ();
		zshape.append_text("Circular");
		zshape.append_text("Polygon");

		ztype = new Gtk.ComboBoxText ();
		ztype.append_text("Exclusive");
		ztype.append_text("Inclusive");

		zaction = new Gtk.ComboBoxText ();
		zaction.append_text("None");
		zaction.append_text("Avoid");
		zaction.append_text("PosHold");
		zaction.append_text("RTH");

		zminalt = new Gtk.Entry();
		zminalt.set_text("0");
		zminalt.set_editable(true);
		zminalt.input_purpose = InputPurpose.NUMBER;

		zmaxalt = new Gtk.Entry();
		zmaxalt.set_text("0");
		zmaxalt.set_editable(true);
		zmaxalt.input_purpose = InputPurpose.NUMBER;

		grid.attach (new Gtk.Label("Index"), 0, 0); // left, top
		grid.attach (zidx, 1, 0);
		grid.attach (new Gtk.Label("Shape"), 0, 1);
		grid.attach (zshape, 1, 1);

		zradius = new Gtk.Entry();
		lradius = new Gtk.Label("Radius (m)");
		grid.attach (lradius, 2, 1);
		grid.attach (zradius, 3, 1);

		grid.attach (new Gtk.Label("Type"), 0, 2);
		grid.attach (ztype, 1, 2);
		grid.attach (new Gtk.Label("Action"), 0, 3);
		grid.attach (zaction, 1, 3);
		grid.attach (new Gtk.Label("Min Altitude (m)"), 0, 4);
		grid.attach (zminalt, 1, 4);
		grid.attach (new Gtk.Label("Max Altitude (m)"), 0, 5);
		grid.attach (zmaxalt, 1, 5);

		vbox.pack_start (grid, false, false, 2);
		set_transient_for (_w);
		set_keep_above(true);
		this.add(vbox);
		nitem = 0;
		buttons[Buttons.PREV].clicked.connect(() => {
				remove_edit_markers();
				newlab.hide();
				if (nitem == 0) {
					if(gzmgr.length() > 0)
						nitem = gzmgr.length()-1;
				} else {
					nitem -= 1;
				}
				set_buttons_sensitive();
				edit_markers();
			});

		buttons[Buttons.NEXT].clicked.connect(() => {
				remove_edit_markers();
				newlab.hide();
				nitem = (nitem + 1) % gzmgr.length();
				set_buttons_sensitive();
				edit_markers();
			});

		buttons[Buttons.REMOVE].clicked.connect(() => {
				remove_current_zone();
			});

		buttons[Buttons.ADD].clicked.connect(() => {
				buttons[Buttons.REMOVE].sensitive = false;
				zshape.sensitive = true;
				new_zone();
			});

		buttons[Buttons.REFRESH].clicked.connect(() => {
				if(nitem >= gzmgr.length()) {
					var minalt = (int)(100* double.parse(zminalt.text));
					var maxalt = (int)(100* double.parse(zmaxalt.text));
					var clat = view.get_center_latitude();
					var clon = view.get_center_longitude();

					if(zshape.active == 0) {
						var rad = double.parse(zradius.text);
						if (rad <= 0.0) {
							return;
						}
						newlab.hide();
						gzmgr.append_zone(nitem, zshape.active, ztype.active, minalt, maxalt, zaction.active);
						gzmgr.append_vertex(nitem, 0, (int)(clat*1e7), (int)(clon*1e7));
						gzmgr.append_vertex(nitem, 1, (int)(rad*100), 0);
					} else {
						newlab.hide();
						gzmgr.append_zone(nitem, zshape.active, ztype.active, minalt, maxalt, zaction.active);
						var delta = 16*Math.pow(2, (20-view.zoom_level));
						double nlat, nlon;
						for(var i = 0; i < 3; i++) {
							Geo.posit(clat, clon, i*120, delta/1852.0, out nlat, out nlon);
							gzmgr.append_vertex(nitem, i, (int)(nlat*1e7), (int)(nlon*1e7));
						}
					}
					var oi = gzmgr.generate_overlay_item(ovl, nitem);
					oi.show_polygon();
					view.add_layer (oi.pl);
					set_buttons_sensitive();
					show_markers();
				} else {
					refresh_storage(Upd.ANY, true);;
				}
			});

		pop_menu = new Gtk.Menu();
		ditem = new Gtk.MenuItem.with_label ("Delete");
		var mitem = new Gtk.MenuItem.with_label ("Insert");
        mitem.activate.connect (() => {
				unowned var el = ovl.get_elements().nth_data(nitem);
				double nlat, nlon;
				Champlain.Label? mk;
				var npts = el.pl.get_nodes().length();
				if(npts == 1) {
					var delta = 16*Math.pow(2, (20-view.zoom_level));
					Geo.posit(popmk.latitude, popmk.longitude, 0, delta/1852.0, out nlat, out nlon);
				} else if(popno == npts - 1) {
					mk = (Champlain.Label)el.pl.get_nodes().nth_data(0);
					nlat = (mk.latitude + popmk.latitude)/2;
					nlon = (mk.longitude + popmk.longitude)/2;
				} else {
					mk = (Champlain.Label)el.pl.get_nodes().nth_data(popno+1);
					nlat = (mk.latitude + popmk.latitude)/2;
					nlon = (mk.longitude + popmk.longitude)/2;
				}
				gzmgr.insert_vertex_at((int)nitem, (int)popno+1,
										   (int)(nlat*1e7), (int)(nlon*1e7));
				mk = el.insert_line_position(nlat, nlon, popno+1);
				ovl.add_marker(mk);
				var id = 0;
				el.pl.get_nodes().foreach((m) => {
						((Champlain.Label)m).text = "%u/%d".printf(nitem, id);
						id++;
					});
				mk.drag_finish.connect(on_poly_finish);
				mk.captured_event.connect(on_poly_capture);
				popmk = null;
				var nv = gzmgr.nvertices(nitem);
				if  (nv > 3)
					ditem.sensitive = true;
			});
        pop_menu.add (mitem);

        ditem.activate.connect (() => {
				gzmgr.remove_vertex_at(nitem, popno);
				if(gzmgr.nvertices(nitem) == 0) {
					remove_current_zone();
				} else {
					var ml = ovl.get_mlayer();
					unowned var el = ovl.get_elements().nth_data(nitem);
					el.pl.remove_node(popmk);
					ml.remove_marker(popmk);
					var id = 0;
					el.pl.get_nodes().foreach((m) => {
							((Champlain.Label)m).text = "%u/%d".printf(nitem, id);
							id++;
						});
				}
				popmk = null;
				var nv = gzmgr.nvertices(nitem);
				if  (nv < 4)
					ditem.sensitive = false;
            });
        pop_menu.add (ditem);
		pop_menu.show_all();
		pop_menu.deactivate.connect(() => {
				popid = -1;
			});

		zshape.changed.connect(() => {
				toggle_shape();
			});

		ztype.changed.connect(() => {
				refresh_storage(Upd.TYPE, true);
			});

		zaction.changed.connect(() => {
				refresh_storage(Upd.ACTION, true);
			});

		zradius.activate.connect(() => {
				refresh_storage(Upd.RADIUS, true);
			});

		zminalt.activate.connect(() => {
				refresh_storage(Upd.MINALT, true);
			});

		zmaxalt.activate.connect(() => {
				refresh_storage(Upd.MAXALT, true);
			});

		set_buttons_sensitive();
	}

	private void refresh_storage(uint8 mask, bool display) {
		uint8 upd = 0; // 1 = colours etc, 0x100 = radius
		var len = gzmgr.length();
		bool valid = (nitem < len);
		if(valid) {
			if((mask & Upd.TYPE) == Upd.TYPE) {
				if ((GeoZoneManager.GZType)ztype.active != gzmgr.get_ztype(nitem)) {
					upd |= Upd.TYPE;
					gzmgr.set_ztype(nitem, (GeoZoneManager.GZType)ztype.active);
				}
			}
			if((mask & Upd.ACTION) == Upd.ACTION) {
				if ((GeoZoneManager.GZAction)zaction.active != gzmgr.get_action(nitem)) {
					upd |= Upd.ACTION;
					gzmgr.set_action(nitem, (GeoZoneManager.GZAction)zaction.active);
				}
			}

			if((mask & Upd.RADIUS) == Upd.RADIUS) {
				if(gzmgr.get_shape(nitem) ==  GeoZoneManager.GZShape.Circular) {
					var nvs = gzmgr.find_vertices(nitem);
					if(nvs.length == 2) {
						int alt = gzmgr.get_latitude(nvs[1]);
						int talt = (int)(1e2*double.parse(zradius.text));
						if(alt != talt) {
							upd |= Upd.RADIUS;
							gzmgr.set_latitude(nvs[1], talt);
						}
					}
				}
			}
			if((mask & Upd.MINALT) == Upd.MINALT) {
				int alt = gzmgr.get_minalt(nitem);
				int talt = (int)(1e2*double.parse(zminalt.text));
				if(alt != talt) {
					upd |= Upd.MINALT;
					gzmgr.set_minalt(nitem, talt);
				}
			}

			if((mask & Upd.MAXALT) == Upd.MAXALT) {
				int alt = gzmgr.get_maxalt(nitem);
				int talt = (int)(1e2*double.parse(zmaxalt.text));
				if(alt != talt) {
					upd |= Upd.MAXALT;
					gzmgr.set_maxalt(nitem, talt);
				}
			}

			if(upd != 0 && display) {
				if((upd & Upd.PROPERTIES) != 0) {
					var el = ovl.get_elements().nth_data(nitem);
					var si = gzmgr.fetch_style(nitem);
					el.update_style(si);
					if (gzmgr.get_shape(nitem) ==  GeoZoneManager.GZShape.Circular) {
						ovl.get_mlayer().get_markers().foreach((mk) => {
								((Champlain.Label)mk).color = Clutter.Color.from_string(si.line_colour);
							});
					}
				}
				if((upd & Upd.RADIUS) != 0) {
					var nvs = gzmgr.find_vertices(nitem);
					if(nvs.length == 2) {
						var el = ovl.get_elements().nth_data(nitem);
						el.circ.radius_nm = gzmgr.get_latitude(nvs[1])/100.0/1852.0;
						var mk = ovl.get_mlayer().get_markers().nth_data(0);
						update_circle(mk);
					}
				}
			}
		}
	}

	private void remove_current_zone() {
		remove_edit_markers();
		gzmgr.remove_zone(nitem);
		ovl.remove_element(nitem);
		nitem = 0;
		set_buttons_sensitive();
		edit_markers();
	}

	private void new_zone() {
		remove_edit_markers();
		string ltext;
		if(zshape.active == 0) {
			ltext = "Once you've filled in the radius (and other fields), click the refresh button to enable the shape";
		} else {
			ltext = "Once you've filled necessary, click the refresh button to enable the shape; click on the map to generate points";
		}
		newlab.set_label(ltext);
		newlab.wrap=true;
		newlab.show();
		grid.attach(newlab, 2, 2, 2, 3);
		nitem = gzmgr.length();
		toggle_shape();
		zidx.set_label(nitem.to_string());
		set_buttons_sensitive();
	}

	private void set_buttons_sensitive() {
		var len = gzmgr.length();
		buttons[Buttons.REMOVE].sensitive = (len > 0);
	}

	private void remove_edit_markers() {
		view.button_release_event.disconnect (on_button_release);
		view.button_press_event.disconnect (on_button_press);
		if(gzmgr.length() > 0) {
			ovl.get_mlayer().get_markers().foreach((mk) => {
					mk.drag_finish.disconnect(on_poly_finish);
					mk.drag_finish.disconnect(on_circ_finish);
					mk.drag_motion.disconnect(on_circ_motion);														});

			ovl.remove_all_markers();
		}
		mk = null;
	}

	public void edit(Overlay? _ovl) {
		ovl = _ovl;
		nitem = 0;
		this.show_all();
		set_buttons_sensitive();
		edit_markers();
	}

	private void set_zradius() {
		double rad = 0.0;
		if(gzmgr.length() > 0 && nitem < gzmgr.length()) {
			if(gzmgr.get_shape(nitem) ==  GeoZoneManager.GZShape.Circular) {
				var nvs = gzmgr.find_vertices(nitem);
				if(nvs.length == 2) {
					rad = gzmgr.get_latitude(nvs[1])/100.0;
				}
			}
		}
		zradius.set_text("%.2f".printf(rad));
	}

	private void init_markers() {
		zidx.set_label("-");
		ztype.active = 0;
		zshape.active = 0;
		zshape.sensitive = true;
		zaction.active = 0;
		zminalt.set_text("0.0");
		zmaxalt.set_text("0.0");
		set_zradius();
		new_zone();
	}

	private void edit_markers() {
		var ulen = gzmgr.length();
		if(ulen > 0) {
			show_markers();
		} else {
			init_markers();
		}
	}

	private void toggle_shape() {
		if (zshape.active == 0) {
			set_zradius();
			lradius.show();
			zradius.show();
		} else {
			lradius.hide();
			zradius.hide();
		}
	}

	public void on_poly_finish(Champlain.Marker mk, Clutter.Event e) {
		var parts = ((Champlain.Label)mk).text.split("/");
		if (parts.length == 2) {
			int vidx = int.parse(parts[1]);
			var k = gzmgr.find_vertex(nitem, vidx);
			gzmgr.set_latitude(k, (int)(mk.latitude*1e7));
			gzmgr.set_longitude(k, (int)(mk.longitude*1e7));
		}
	}

	public bool on_button_press (Clutter.Actor a, Clutter.ButtonEvent event) {
		if (event.button == 1) {
			llat = view.get_center_latitude();
			llon = view.get_center_longitude();
		}
		return false;
	}

	public bool on_button_release (Clutter.Actor a, Clutter.ButtonEvent event) {
		double lat, lon;
		if (event.button == 1) {
			if (popid != -2) {
				lat = view.get_center_latitude();
				lon = view.get_center_longitude();
				if((!view_delta_diff(llon,lon) && !view_delta_diff(llat,lat))) {
					lat = view.y_to_latitude (event.y);
					lon = view.x_to_longitude (event.x);
					add_polypoint(lat, lon);
				}
			}
		}
		return false;
	}

	private void update_circle(Champlain.Marker mk) {
		unowned var el = ovl.get_elements().nth_data(nitem);
		var pts = el.pl.get_nodes();
		var j = 0;
		for (var i = 0; i < 360; i += 5) {
			double plat, plon;
			Geo.posit(mk.latitude, mk.longitude, i, el.circ.radius_nm, out plat, out plon);
			pts.nth_data(j).latitude = plat;
			pts.nth_data(j).longitude = plon;
			j++;
		}
	}

	public void on_circ_motion(Champlain.Marker mk, double x, double y, Clutter.Event e) {
		update_circle(mk);
	}

	public void on_circ_finish(Champlain.Marker mk, Clutter.Event e) {
		unowned var el = ovl.get_elements().nth_data(nitem);
		el.circ.lat = mk.latitude;
		int k = gzmgr.find_vertex(nitem, 0);
		gzmgr.set_latitude(k, (int)(mk.latitude*1e7));
		el.circ.lon = mk.longitude;
		gzmgr.set_longitude(k, (int)(mk.longitude*1e7));
	}

	public bool on_poly_capture(Clutter.Actor mk, Clutter.Event e) {
		if(e.get_type() == Clutter.EventType.BUTTON_PRESS) {
			if(e.button.button == 3) {
				var parts = ((Champlain.Label)mk).text.split("/");
				if (parts.length == 2) {
					popid = int.parse(parts[1]);
					popmk = (Champlain.Label)mk;
					var nv = gzmgr.nvertices(nitem);
					ditem.sensitive = (nv > 3);
				}
			}
		}
		return false;
	}

	private void add_polypoint(double lat, double lon) {
		var vlen = gzmgr.nvertices(nitem);
		gzmgr.append_vertex(nitem, vlen, (int)(lat*1e7), (int)(lon*1e7));
		unowned var el = ovl.get_elements().nth_data(nitem);
		var mk = el.add_line_point(lat,lon, "%u/%u".printf(nitem, vlen));
		ovl.add_marker(mk);
		mk.drag_finish.connect(on_poly_finish);
		mk.captured_event.connect(on_poly_capture);
	}

	public bool popup(Gdk.Event e) {
		if(popid < 0) {
			return false;
		} else {
			popno = popid;
			popid = -2;
			pop_menu.popup_at_pointer(e);
			return true;
		}
	}

	private void show_markers() {
		zidx.set_label(nitem.to_string());
		ztype.active = (int)gzmgr.get_ztype(nitem);
		zshape.active = (int)gzmgr.get_shape(nitem);
		zshape.sensitive = false;
		zaction.active = (int)gzmgr.get_action(nitem);
		zminalt.set_text("%.2f".printf(gzmgr.get_minalt(nitem)/100.0));
		zmaxalt.set_text("%.2f".printf(gzmgr.get_maxalt(nitem)/100.0));
		toggle_shape();
		unowned var el = ovl.get_elements().nth_data(nitem);
		if(el.circ.radius_nm == 0) {
			int nz = 0;
			view.button_release_event.connect (on_button_release);
			view.button_press_event.connect (on_button_press);
			el.pl.get_nodes().foreach((mk) => {
					var pname = "%d/%d".printf(el.idx, nz);
					el.set_label((Champlain.Label)mk, pname);
					((Champlain.Label)mk).visible = true;
					((Champlain.Label)mk).draggable = true;
					ovl.add_marker((Champlain.Label)mk);
					((Champlain.Label)mk).drag_finish.connect(on_poly_finish);
					((Champlain.Label)mk).captured_event.connect(on_poly_capture);
					nz++;
				});
		} else {
			mk = new Champlain.Label();
			Clutter.Color black = { 0,0,0, 0xff };
			mk.set_text("%d/0".printf(el.idx));
			mk.set_font_name("Sans 10");
			mk.set_alignment (Pango.Alignment.RIGHT);
			mk.set_color(Clutter.Color.from_string(el.styleinfo.line_colour));
			mk.set_text_color(black);
			mk.set_draggable(true);
			mk.set_selectable(false);
			mk.latitude = el.circ.lat;
			mk.longitude = el.circ.lon;
			ovl.add_marker(mk);
			mk.drag_motion.connect(on_circ_motion);
			mk.drag_finish.connect(on_circ_finish);
		}
	}

    private bool view_delta_diff(double f0, double f1) {
        double delta;
        delta = 0.0000025 * Math.pow(2, (20-view.zoom_level));
        var res = (Math.fabs(f0-f1) > delta);
        return res;
    }
}
