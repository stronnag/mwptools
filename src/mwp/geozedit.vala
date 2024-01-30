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
	private GeoZoneReader gzr;
	private Gtk.Label lradius;
	private Gtk.Grid grid;
	private Gtk.Label newlab;
    private Gtk.Menu pop_menu;
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


	public GZEdit(Gtk.Window? _w=null, GeoZoneReader _gzr) {
		gzr = _gzr;
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
					if(gzr.length() > 0)
						nitem = gzr.length()-1;
				} else {
					nitem -= 1;
				}
				set_buttons_sensitive();
				edit_markers();
			});

		buttons[Buttons.NEXT].clicked.connect(() => {
				remove_edit_markers();
				newlab.hide();
				nitem = (nitem + 1) % gzr.length();
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
				if(nitem >= gzr.length()) {
					var minalt = (int)(100* double.parse(zminalt.text));
					var maxalt = (int)(100* double.parse(zmaxalt.text));
					var z = gzr.nth_data(nitem);
					if(zshape.active == 0) {
						var rad = double.parse(zradius.text);
						if (rad <= 0.0) {
							return;
						}
						newlab.hide();
						var clat = ovl.get_view().get_center_latitude();
						var clon = ovl.get_view().get_center_longitude();
						gzr.append_zone(nitem, zshape.active, ztype.active, minalt, maxalt, zaction.active);
						gzr.append_vertex((int)nitem, 0, (int)(clat*1e7), (int)(clon*1e7));
						gzr.append_vertex((int)nitem, 1, (int)(rad*100), 0);
						var oi = gzr.generate_overlay_item(ovl, z, (int)nitem);
						oi.show_polygon();
						ovl.get_view().add_layer (oi.pl);
						show_markers();
					} else {
						newlab.hide();
						gzr.append_zone(nitem, zshape.active, ztype.active, minalt, maxalt, zaction.active);
						var oi = gzr.generate_overlay_item(ovl, z, (int)nitem);
						oi.show_polygon();
						ovl.get_view().add_layer (oi.pl);
						show_markers();
					}
				} else {
					refresh_storage(Upd.ANY, true);
				}
			});

		pop_menu = new Gtk.Menu();
		var mitem = new Gtk.MenuItem.with_label ("Insert");
        mitem.activate.connect (() => {
				unowned var el = ovl.get_elements().nth_data(nitem);
				double nlat, nlon;
				Champlain.Label? mk;
				var npts = el.pl.get_nodes().length();
				if(npts == 1) {
					nlat = popmk.latitude + 0.001;
					nlon = popmk.longitude + 0.0001;
				} else if(popno == npts - 1) {
					mk = (Champlain.Label)el.pl.get_nodes().nth_data(0);
					nlat = (mk.latitude + popmk.latitude)/2;
					nlon = (mk.longitude + popmk.longitude)/2;
				} else {
					mk = (Champlain.Label)el.pl.get_nodes().nth_data(popno+1);
					nlat = (mk.latitude + popmk.latitude)/2;
					nlon = (mk.longitude + popmk.longitude)/2;
				}
				gzr.insert_vertex_position((int)nitem, (int)popno+1,
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
			});
        pop_menu.add (mitem);
		mitem = new Gtk.MenuItem.with_label ("Delete");
        mitem.activate.connect (() => {
				var z = gzr.nth_data(nitem);
				//var d = gzr.nth_data(nitem).vertices.nth_data(popno);
				unowned var l = z.vertices.nth(popno);
				//z.vertices.remove(d);
				z.vertices.remove_link(l);
				if(z.vertices.length() == 0) {
					remove_current_zone();
				} else {
					uint8 j = 0;
					z.vertices.foreach((v) => {
							v.index = j;
							j++;
						});
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
            });
        pop_menu.add (mitem);
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
		var len = gzr.length();
		bool valid = (nitem < len);
		if(valid) {
			if((mask & Upd.TYPE) == Upd.TYPE) {
				if ((GeoZoneReader.GZType)ztype.active != gzr.get_ztype(nitem)) {
					upd |= Upd.TYPE;
					gzr.set_ztype(nitem, (GeoZoneReader.GZType)ztype.active);
				}
			}
			if((mask & Upd.ACTION) == Upd.ACTION) {
				if ((GeoZoneReader.GZAction)zaction.active != gzr.get_action(nitem)) {
					upd |= Upd.ACTION;
					gzr.set_action(nitem, (GeoZoneReader.GZAction)zaction.active);
				}
			}

			if((mask & Upd.RADIUS) == Upd.RADIUS) {
				unowned var z = gzr.nth_data(nitem);
				if(z.shape ==  GeoZoneReader.GZShape.Circular) {
					if(z.vertices.length() == 2) {
						int alt = z.vertices.nth_data(1).latitude;
						int talt = (int)(1e2*double.parse(zradius.text));
						if(alt != talt) {
							upd |= Upd.RADIUS;
							z.vertices.nth_data(1).latitude = talt;
						}
					}
				}
			}
			if((mask & Upd.MINALT) == Upd.MINALT) {
				int alt = gzr.get_minalt(nitem);
				int talt = (int)(1e2*double.parse(zminalt.text));
				if(alt != talt) {
					upd |= Upd.MINALT;
					gzr.set_minalt(nitem, talt);
				}
			}

			if((mask & Upd.MAXALT) == Upd.MAXALT) {
				int alt = gzr.get_maxalt(nitem);
				int talt = (int)(1e2*double.parse(zmaxalt.text));
				if(alt != talt) {
					upd |= Upd.MAXALT;
					gzr.set_maxalt(nitem, talt);
				}
			}

			if(upd != 0 && display) {
				if((upd & Upd.PROPERTIES) != 0) {
					var el = ovl.get_elements().nth_data(nitem);
					var si = gzr.fetch_style(nitem);
					el.update_style(si);
					if (gzr.nth_data(nitem).shape ==  GeoZoneReader.GZShape.Circular) {
						ovl.get_mlayer().get_markers().foreach((mk) => {
								((Champlain.Label)mk).color = Clutter.Color.from_string(si.line_colour);
							});
					}
				}
				if((upd & Upd.RADIUS) != 0) {
					var el = ovl.get_elements().nth_data(nitem);
					el.circ.radius_nm = gzr.nth_data(nitem).vertices.nth_data(1).latitude/100.0/1852.0;
					var mk = ovl.get_mlayer().get_markers().nth_data(0);
					update_circle(mk);
				}

			}
		}
	}

	private void remove_current_zone() {
		remove_edit_markers();
		gzr.remove_zone(nitem);
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
		nitem = gzr.length();
		toggle_shape();
		zidx.set_label(nitem.to_string());
		set_buttons_sensitive();
	}

	private void set_buttons_sensitive() {
		var len = gzr.length();

		buttons[Buttons.REMOVE].sensitive = (len > 0);
		//		if (len > 1)  {
		//	buttons[Buttons.PREV].sensitive = (nitem != 0);
		//	buttons[Buttons.NEXT].sensitive = (nitem < len -1);
		//}
	}

	private void remove_edit_markers() {
		ovl.get_view().button_release_event.disconnect (on_button_release);
		if(gzr.length() > 0) {
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
		if(gzr.length() > 0 && nitem < gzr.length()) {
			var z = gzr.nth_data(nitem);
			if(z.shape ==  GeoZoneReader.GZShape.Circular) {
				if(z.vertices.length() == 2) {
					rad = z.vertices.nth_data(1).latitude/100.0;
				}
			}
		}
		/*
		stderr.printf("DBG: %u zradius %u %u %.2f\n", nitem, gzr.nth_data(nitem).shape,
					  gzr.nth_data(nitem).vertices.length(),
					  rad);
		for(var i = 0; i < 2; i++) {
			stderr.printf("DBG:  %d la = %d lo = %d\n", i,
						  gzr.nth_data(nitem).vertices.nth_data(i).latitude,
						  gzr.nth_data(nitem).vertices.nth_data(i).longitude);
		}
		*/
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
		var ulen = gzr.length();
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
			var z = gzr.nth_data(nitem);
			int vlen = int.parse(parts[1]);
			z.vertices.nth_data(vlen).latitude = (int) (mk.latitude*1e7);
			z.vertices.nth_data(vlen).longitude =  (int)(mk.longitude*1e7);
		}
	}

	public bool on_button_release (Clutter.Actor a, Clutter.ButtonEvent event) {
		double lat, lon;
		if (event.button == 1) {
			if(popid != -2) {
				lat = ovl.get_view().y_to_latitude (event.y);
				lon = ovl.get_view().x_to_longitude (event.x);
				add_polypoint(lat, lon);
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
		var z = gzr.nth_data(nitem);
		z.vertices.nth_data(0).latitude = (int) (mk.latitude*1e7);
		el.circ.lon = mk.longitude;
		z.vertices.nth_data(0).longitude =  (int)(mk.longitude*1e7);
	}

	public bool on_poly_capture(Clutter.Actor mk, Clutter.Event e) {
		if(e.get_type() == Clutter.EventType.BUTTON_PRESS) {
			if(e.button.button == 3) {
				var parts = ((Champlain.Label)mk).text.split("/");
				if (parts.length == 2) {
					popid = int.parse(parts[1]);
					popmk = (Champlain.Label)mk;
				}
			}
		}
		return false;
	}

	private void add_polypoint(double lat, double lon) {
		var z = gzr.nth_data(nitem);
		var vlen = z.vertices.length();
		gzr.append_vertex((int)nitem, (int)vlen,
										  (int)(lat*1e7), (int)(lon*1e7));
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
		var z = gzr.nth_data(nitem);
		zidx.set_label(nitem.to_string());
		ztype.active = (int)z.type;
		zshape.active = (int)z.shape;
		zshape.sensitive = false;
		zaction.active = (int)z.action;
		zminalt.set_text("%.2f".printf(z.minalt/100.0));
		zmaxalt.set_text("%.2f".printf(z.maxalt/100.0));
		toggle_shape();
		unowned var el = ovl.get_elements().nth_data(nitem);
		if(el.circ.radius_nm == 0) {
			int nz = 0;
			ovl.get_view().button_release_event.connect (on_button_release);

			el.mks.foreach((mk) => {
					var pname = "%d/%d".printf(el.idx, nz);
					el.set_label(mk, pname);
					mk.visible = true;
					mk.draggable = true;
					ovl.add_marker(mk);
					mk.drag_finish.connect(on_poly_finish);
					mk.captured_event.connect(on_poly_capture);
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
}
