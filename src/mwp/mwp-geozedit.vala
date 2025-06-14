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

using Gtk;

public class GZEdit : Adw.Window {
	private Gtk.Label zidx;
	private Gtk.DropDown zshape;
	private Gtk.DropDown ztype;
	private Gtk.DropDown zaction;
	private Gtk.Entry zminalt;
	private Gtk.Entry zmaxalt;
	private Gtk.Switch zisamsl;
	private Gtk.Entry zradius;
	private Gtk.Button[] buttons;
	private uint nitem;
	private MWPMarker? mk;
	private Overlay? ovl;
	private GeoZoneManager gzmgr;
	private Gtk.Label lradius;
	private Gtk.Grid grid;
	private Gtk.Label newlab;

	private unowned MWPMarker? popmk;
	private int popno;
	private Gtk.PopoverMenu pop;
	private GLib.MenuModel menu;
	private GLib.SimpleActionGroup dg;

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
		ISAMSL = 0x80,
		PROPERTIES = 0xf,
		ANY = 0xff,
	}

	const string NEWLAB="Once you've set any required fields (including <b>radius</b> for circles), click the <b>REFRESH</b> button to enable the shape";

	public GZEdit() {
		var gbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);

		var tbox = new Adw.ToolbarView();
		var header_bar = new Adw.HeaderBar();
		tbox.add_top_bar(header_bar);

		GLib.SimpleAction aq;
		dg = new GLib.SimpleActionGroup();

		default_width = 600;

		gzmgr = Mwp.gzr;

		var sbuilder = new Gtk.Builder.from_resource ("/org/stronnag/mwp/gzmenu.ui");
		menu = sbuilder.get_object("gz-menu") as GLib.MenuModel;

		aq = new GLib.SimpleAction("gzinsert", null);
		aq.activate.connect(() => {
				unowned OverlayItem el = ovl.get_elements().nth_data(nitem);
				double nlat, nlon;
				nlat = 0.0;
				nlon = 0.0;
				MWPMarker? mk;
				var npts = el.pl.get_nodes().length();
				if(npts == 1) {
					var delta = 16*Math.pow(2, (20-Gis.map.viewport.zoom_level));
					Geo.posit(popmk.latitude, popmk.longitude, 0, delta/1852.0, out nlat, out nlon);
				} else if(popno == npts - 1) {
					mk = (MWPLabel)el.pl.get_nodes().nth_data(0);
					nlat = (mk.latitude + popmk.latitude)/2;
					nlon = (mk.longitude + popmk.longitude)/2;
				} else {
					mk = (MWPLabel)el.pl.get_nodes().nth_data(popno+1);
					nlat = (mk.latitude + popmk.latitude)/2;
					nlon = (mk.longitude + popmk.longitude)/2;
				}
				var nv = Mwp.gzr.nvertices(nitem);
				Mwp.gzr.insert_vertex_at((int)nitem, (int)popno+1,
										 (int)(nlat*1e7), (int)(nlon*1e7));

				nv = Mwp.gzr.nvertices(nitem);

				mk = el.insert_line_position(nlat, nlon, popno+1);
				el.set_label((MWPLabel)mk, "?");
				ovl.add_marker(mk);

				var id = 0;
				el.pl.get_nodes().foreach((m) => {
						((MWPLabel)m).set_text("%u/%d".printf(nitem, id));
						id++;
					});
				mk.popup_request.connect(on_poly_capture);
				nv = Mwp.gzr.nvertices(nitem);
				validate(nv);
				if  (nv > 3) {
					MwpMenu.set_menu_state(Mwp.window, "gzdelete", true);
				}
				mk.drag_end.connect(on_poly_finish);

			});
		dg.add_action(aq);
		aq = new GLib.SimpleAction("gzdelete", null);
		aq.activate.connect(() => {
				Mwp.gzr.remove_vertex_at(nitem, popno);
				unowned OverlayItem el = ovl.get_elements().nth_data(nitem);
				var ml = ovl.get_mlayer();
				var i = 0;
				el.pl.get_nodes().foreach( (e) => {
						if(i == popno) {
							((MWPMarker)e).drag_end.disconnect(on_poly_finish);
							((MWPMarker)e).popup_request.disconnect(on_poly_capture);
							el.pl.remove_node(e);
							ml.remove_marker((MWPLabel)e);
						} else if (i > popno) {
							((MWPLabel)e).set_text("%u/%d".printf(nitem, i-1));
						}
						i++;
					});
				var nv = Mwp.gzr.nvertices(nitem);
				validate(nv);
				if  (nv < 4) {
					MwpMenu.set_menu_state(Mwp.window, "gzdelete", false);
				}
			});
		dg.add_action(aq);
		Mwp.window.insert_action_group("geoz", dg);
		title = "mwp GeoZone Editor";
		this.close_request.connect (() => {
				refresh_storage(Upd.ANY, false);
				remove_edit_markers();
				visible=false;
				return true;
			});

		buttons = {
			new Gtk.Button.from_icon_name ("list-add-symbolic"),
			new Gtk.Button.from_icon_name ("go-previous-symbolic"),
			new Gtk.Button.from_icon_name ("go-next-symbolic"),
			new Gtk.Button.from_icon_name ("list-remove-symbolic"),
			new Gtk.Button.from_icon_name ("view-refresh-symbolic"),
		};

		newlab = new Gtk.Label(null);
		newlab.set_use_markup(true);
		newlab.wrap=true;
		newlab.label = NEWLAB;

		Gtk.Box bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL,2);
		bbox.set_spacing (16);
		bbox.hexpand = true;
		bbox.halign = Gtk.Align.FILL;
		bbox.add_css_class("toolbar");
		tbox.add_bottom_bar(bbox);

		foreach (unowned Gtk.Button button in buttons) {
			bbox.append (button);
			button.hexpand = true;
			button.halign = Gtk.Align.BASELINE_CENTER;
		}

		buttons[0].set_tooltip_text("Add new shape");
		buttons[1].set_tooltip_text("Previous shape");
		buttons[2].set_tooltip_text("Next shape");
		buttons[3].set_tooltip_text("Delete current shape");
		buttons[4].set_tooltip_text("Refresh");

		var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
		vbox.hexpand = false;

		grid = new Gtk.Grid ();

		zidx = new Gtk.Label("-");

		zshape = new Gtk.DropDown.from_strings({"Circular", "Polygon"});
		ztype = new Gtk.DropDown.from_strings({"Exclusive", "Inclusive"});
		zaction = new Gtk.DropDown.from_strings({"None", "Avoid", "PosHold", "RTH"});

		zminalt = new Gtk.Entry();
		zminalt.set_text("0");
		zminalt.set_editable(true);
		zminalt.input_purpose = InputPurpose.NUMBER;

		zmaxalt = new Gtk.Entry();
		zmaxalt.set_text("0");
		zmaxalt.set_editable(true);
		zmaxalt.input_purpose = InputPurpose.NUMBER;

		zisamsl = new Gtk.Switch();
		zisamsl.hexpand = false;
		zisamsl.vexpand = false;
		zisamsl.halign = Gtk.Align.START;
		zisamsl.valign = Gtk.Align.START;

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
		grid.attach (new Gtk.Label("is AMSL"), 0, 6);
		grid.attach (zisamsl, 1, 6);

		grid.column_homogeneous = true;
		vbox.append (grid);
		set_transient_for (Mwp.window);

		gbox.append(vbox);
		tbox.set_content(gbox);
		set_content(tbox);

		nitem = 0;
		buttons[Buttons.PREV].clicked.connect(() => {
				if(Mwp.gzr.length() > 0) {
					refresh_storage(Upd.ANY, false);
					remove_edit_markers();
					newlab.label="";
					if (nitem == 0) {
						nitem = Mwp.gzr.length()-1;
					} else {
						nitem -= 1;
					}
					set_buttons_sensitive();
					edit_markers();
				}
			});

		buttons[Buttons.NEXT].clicked.connect(() => {
				if(Mwp.gzr.length() > 0) {
					refresh_storage(Upd.ANY, false);
					remove_edit_markers();
					newlab.label="";
					nitem = (nitem + 1) % Mwp.gzr.length();
					set_buttons_sensitive();
					edit_markers();
				}
			});

		buttons[Buttons.REMOVE].clicked.connect(() => {
				if(Mwp.gzr.length() > 0) {
					remove_current_zone();
				}
			});

		buttons[Buttons.ADD].clicked.connect(() => {
				buttons[Buttons.REMOVE].sensitive = false;
				zshape.sensitive = true;
				new_zone();
			});

		buttons[Buttons.REFRESH].clicked.connect(() => {
				if(nitem >= Mwp.gzr.length()) {
					refresh_storage(Upd.ANY, false);
					var minalt = (int)(100* DStr.strtod(zminalt.text, null));
					var maxalt = (int)(100* DStr.strtod(zmaxalt.text, null));
					var isamsl = (uint8)zisamsl.active;
					double clat = 0;
					double clon = 0;
					MapUtils.get_centre_location(out clat, out clon);
					int k=-1;
					if(zshape.selected == 0) {
						var rad = DStr.strtod(zradius.text, null);
						if (rad <= 0.0) {
							return;
						}
						newlab.label="";
						Mwp.gzr.append_zone(nitem, (GeoZoneManager.GZShape)zshape.selected,
										  (GeoZoneManager.GZType)ztype.selected,
											minalt, maxalt, isamsl,
										  (GeoZoneManager.GZAction)zaction.selected);
						k = Mwp.gzr.append_vertex(nitem, 0, (int)(clat*1e7), (int)(clon*1e7));
						k = Mwp.gzr.append_vertex(nitem, 1, (int)(rad*100), 0);
					} else {
						newlab.label="";
						Mwp.gzr.append_zone(nitem,
											(GeoZoneManager.GZShape)zshape.selected,
											(GeoZoneManager.GZType)ztype.selected,
											minalt, maxalt, 0, // FIXME
											(GeoZoneManager.GZAction)zaction.selected);
						var delta = 16*Math.pow(2, (20-Gis.map.viewport.zoom_level));
						double nlat, nlon;
						for(var i = 0; i < 3; i++) {
							Geo.posit(clat, clon, 360-i*120, delta/1852.0, out nlat, out nlon);
							k = Mwp.gzr.append_vertex(nitem, i, (int)(nlat*1e7), (int)(nlon*1e7));
						}
					}
					if(k == -1) {
						MWPLog.message("failed to add zone %u\n", nitem);
						Mwp.gzr.remove_zone(nitem);
						return;
					}
					var oi = Mwp.gzr.generate_overlay_item(ovl, nitem);
					oi.show_polygon();
					Gis.map.insert_layer_above(oi.pl, Gis.base_layer);
					set_buttons_sensitive();
					show_markers();
				} else {
					refresh_storage(Upd.ANY, true);
				}
			});

		zshape.notify["selected"].connect(() => {
				toggle_shape();
			});

		ztype.notify["selected"].connect(() => {
				refresh_storage(Upd.TYPE, true);
			});

		zaction.notify["selected"].connect(() => {
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

		zisamsl.activate.connect(() => {
				refresh_storage(Upd.ISAMSL, true);
			});

		grid.attach(newlab, 2, 2, 2, 4);
		set_buttons_sensitive();
	}

	private void set_buttons_sensitive() {
		var len = Mwp.gzr.length();
		buttons[Buttons.REMOVE].sensitive = (len > 0);
	}

	public void edit(Overlay? _ovl) {
		ovl = _ovl;
		nitem = 0;
		set_buttons_sensitive();
		edit_markers();
		present();
	}

		private void set_zradius() {
		double rad = 0.0;
		if(Mwp.gzr.length() > 0 && nitem < Mwp.gzr.length()) {
			if(Mwp.gzr.get_shape(nitem) ==  GeoZoneManager.GZShape.Circular) {
				var nvs = Mwp.gzr.find_vertices(nitem);
				if(nvs.length == 2) {
					rad = Mwp.gzr.get_latitude(nvs[1])/100.0;
				}
			}
		}
		zradius.set_text("%.2f".printf(rad));
	}

	private void init_markers(bool rm = true) {
		zidx.set_label("-");
		ztype.selected = 0;
		zshape.selected = 0;
		zshape.sensitive = true;
		zaction.selected = 0;
		zminalt.set_text("0.0");
		zmaxalt.set_text("0.0");
		set_zradius();
 		new_zone(rm);
	}

	private void edit_markers() {
		var ulen = Mwp.gzr.length();
		if(ulen > 0) {
			show_markers();
		} else {
			init_markers();
		}
	}


	private void show_markers() {
		//newlab.label=NEWLAB;
		zidx.set_label(nitem.to_string());
		ztype.selected = (int)Mwp.gzr.get_ztype(nitem);
		zshape.selected = (int)Mwp.gzr.get_shape(nitem);
		zshape.sensitive = false;
		zaction.selected = (int)Mwp.gzr.get_action(nitem);
		zminalt.set_text("%.2f".printf(Mwp.gzr.get_minalt(nitem)/100.0));
		zmaxalt.set_text("%.2f".printf(Mwp.gzr.get_maxalt(nitem)/100.0));
		zisamsl.active = (bool) Mwp.gzr.get_amsl(nitem);
		toggle_shape();
		unowned OverlayItem el = ovl.get_elements().nth_data(nitem);
		if(el.circ.radius_nm == 0) { // polyline
			int nz = 0;
			el.pl.get_nodes().foreach((mk) => {
					var pname = "%d/%d".printf(el.idx, nz);
					el.set_label((MWPLabel)mk, pname);
					((MWPLabel)mk).visible = true;
					((MWPLabel)mk).set_draggable(true);
					ovl.add_marker((MWPLabel)mk);
					((MWPLabel)mk).drag_end.connect(on_poly_finish);
					((MWPLabel)mk).popup_request.connect(on_poly_capture);
					nz++;
				});
		} else {  // circle
			var mk = new MWPLabel();
			var c = el.styleinfo.line_colour;
			mk.set_colour(c);
			mk.set_text("%d/0".printf(el.idx));
			mk.set_draggable(true);
			mk.latitude = el.circ.lat;
			mk.longitude = el.circ.lon;
			ovl.add_marker(mk);
			mk.drag_motion.connect(on_circ_motion);
			mk.drag_end.connect(on_circ_finish);
		}
	}

	private void toggle_shape() {
		if (zshape.selected == 0) {
			set_zradius();
			lradius.visible=true;
			zradius.visible=true;
		} else {
			lradius.visible=false;
			zradius.visible=false;
		}
	}

	private void remove_edit_markers(bool am = true) {
		if(Mwp.gzr.length() > 0) {
			var ml = ovl.get_mlayer();
			if(ml != null) {
				ovl.get_mlayer().get_markers().foreach((mk) => {
						((MWPMarker)mk).drag_end.disconnect(on_poly_finish);
						((MWPMarker)mk).popup_request.disconnect(on_poly_capture);
						((MWPMarker)mk).drag_end.disconnect(on_circ_finish);
						((MWPMarker)mk).drag_motion.disconnect(on_circ_motion);
					});
				if(am)
					ovl.remove_all_markers();
			}
		}
		mk = null;
	}

	private void validate(uint nv) {
		var ok = true;
		unowned OverlayItem el = ovl.get_elements().nth_data(nitem);
		StringBuilder sb = new StringBuilder("Validate \n");
		for(var j = 0; j < nv; j++) {
			var df = 0;
			var k = Mwp.gzr.find_vertex(nitem, j);
			var lat = Mwp.gzr.get_latitude(k)/1e7;
			var lon = Mwp.gzr.get_longitude(k)/1e7;
			sb.append_printf("BUG: V: %f %f ", lat, lon);
			var mk = (MWPLabel)el.pl.get_nodes().nth_data(j);
			var lname = ((Gtk.Label)mk.get_child()).label;
			var parts=lname.split("/");
			var _nitem = int.parse(parts[0]);
			var _j = int.parse(parts[1]);
			sb.append_printf("P:%s%f %f", lname, mk.latitude, mk.longitude);
			if(nitem != _nitem || j != _j)
				df |= 1;
			if (!same_pos(lat, mk.latitude))
				df |= 2;
			if (!same_pos(lon, mk.longitude))
				df |= 4;
			if(df != 0) {
				sb.append_printf(" %x ****************", df);
				ok = false;
			}
			sb.append_c('\n');
		}
		if(!ok) {
			MWPLog.message(sb.str);
			MWPLog.message("BUG:  ******* Conistency Error *********\n");
		}
	}

	private bool same_pos(double f1, double f0) {
		return (Math.fabs(f1-f0) < 1e6);
	}

	private void refresh_storage(uint8 mask, bool display) {
		uint8 upd = 0; // 1 = colours etc, 0x100 = radius
		var len = Mwp.gzr.length();
		bool valid = (nitem < len);
		if(valid) {
			if((mask & Upd.TYPE) == Upd.TYPE) {
				if ((GeoZoneManager.GZType)ztype.selected != Mwp.gzr.get_ztype(nitem)) {
					upd |= Upd.TYPE;
					Mwp.gzr.set_ztype(nitem, (GeoZoneManager.GZType)ztype.selected);
				}
			}
			if((mask & Upd.ACTION) == Upd.ACTION) {
				if ((GeoZoneManager.GZAction)zaction.selected != Mwp.gzr.get_action(nitem)) {
					upd |= Upd.ACTION;
					Mwp.gzr.set_action(nitem, (GeoZoneManager.GZAction)zaction.selected);
				}
			}

			if((mask & Upd.RADIUS) == Upd.RADIUS) {
				if(Mwp.gzr.get_shape(nitem) ==  GeoZoneManager.GZShape.Circular) {
					var nvs = Mwp.gzr.find_vertices(nitem);
					if(nvs.length == 2) {
						int alt = Mwp.gzr.get_latitude(nvs[1]);
						int talt = (int)(1e2*DStr.strtod(zradius.text, null));
						if(alt != talt) {
							upd |= Upd.RADIUS;
							Mwp.gzr.set_latitude(nvs[1], talt);
						}
					}
				}
			}
			if((mask & Upd.MINALT) == Upd.MINALT) {
				int alt = Mwp.gzr.get_minalt(nitem);
				int talt = (int)(1e2*DStr.strtod(zminalt.text, null));
				if(alt != talt) {
					upd |= Upd.MINALT;
					Mwp.gzr.set_minalt(nitem, talt);
				}
			}

			if((mask & Upd.MAXALT) == Upd.MAXALT) {
				int alt = Mwp.gzr.get_maxalt(nitem);
				int talt = (int)(1e2*DStr.strtod(zmaxalt.text, null));
				if(alt != talt) {
					upd |= Upd.MAXALT;
					Mwp.gzr.set_maxalt(nitem, talt);
				}
			}

			if((mask & Upd.ISAMSL) == Upd.ISAMSL) {
				upd |= Upd.ISAMSL;
				Mwp.gzr.set_amsl(nitem, (uint8)zisamsl.active);
			}

			if(upd != 0 && display) {
				if((upd & Upd.PROPERTIES) != 0) {
					var el = ovl.get_elements().nth_data(nitem);
					var si = Mwp.gzr.fetch_style(nitem);
					el.update_style(si);
					if (Mwp.gzr.get_shape(nitem) ==  GeoZoneManager.GZShape.Circular) {
						var ml = ovl.get_mlayer();
						if(ml != null) {
							ml.get_markers().foreach((mk) => {
									((MWPLabel)mk).set_colour (si.line_colour);
							});
						}
					}
				}
				if((upd & Upd.RADIUS) != 0) {
					var nvs = Mwp.gzr.find_vertices(nitem);
					if(nvs.length == 2) {
						var el = ovl.get_elements().nth_data(nitem);
						el.circ.radius_nm = Mwp.gzr.get_latitude(nvs[1])/100.0/1852.0;
						var mk = ovl.get_mlayer().get_markers().nth_data(0);
						update_circle((MWPLabel)mk);
					}
				}
			}
		}
	}

	private void remove_current_zone() {
		remove_edit_markers();
		Mwp.gzr.remove_zone(nitem);
		ovl.remove_element(nitem);
		nitem = 0;
		set_buttons_sensitive();
		edit_markers();
	}

	private void new_zone(bool rm = true) {
		remove_edit_markers(rm);
		newlab.label=NEWLAB;
		nitem = Mwp.gzr.length();
		toggle_shape();
		zidx.set_label(nitem.to_string());
		set_buttons_sensitive();
	}


	/**
	private void dump_points() {
		unowned OverlayItem el = ovl.get_elements().nth_data(nitem);
		var pts = el.pl.get_nodes();
		pts.foreach((pt) => {
				stderr.printf("DBG: Point <%s>\n", ((Champlain.Label)pt).text);
			});
	}
	*/

	public void on_poly_finish(MWPMarker mk, bool t) {
		var txt = ((Gtk.Label)((MWPLabel)mk).get_child()).label;
		if (txt != null) {
			var parts = txt.split("/");
			if (parts.length == 2) {
				int vidx = int.parse(parts[1]);
				var k = Mwp.gzr.find_vertex(nitem, vidx);
				if (k != -1) {
					Mwp.gzr.set_latitude(k, (int)(mk.latitude*1e7));
					Mwp.gzr.set_longitude(k, (int)(mk.longitude*1e7));
				} else {
					MWPLog.message("**BUG** Failed to lookup \"%s\" %u/%d\n", txt, nitem, vidx);
					//Mwp.gzr.dump_vertices(nitem);
					//dump_points();
				}
			}
		}
	}

	public void on_circ_motion(MWPMarker mk, double x, double y) {
		update_circle(mk);
	}

	public void update_circle(MWPMarker mk) {
		unowned OverlayItem el = ovl.get_elements().nth_data(nitem);
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

	public void on_circ_finish(MWPMarker mk, bool t) {
		unowned OverlayItem elm = ovl.get_elements().nth_data(nitem);
		elm.circ.lat = mk.latitude;
		int k = Mwp.gzr.find_vertex(nitem, 0);
		if (k != -1) {
			Mwp.gzr.set_latitude(k, (int)(mk.latitude*1e7));
			elm.circ.lon = mk.longitude;
			Mwp.gzr.set_longitude(k, (int)(mk.longitude*1e7));
		} else {
			MWPLog.message("**BUG** failed to find circ vertext %u\n", nitem);
		}
	}

	public void on_poly_capture(MWPMarker mk, int n, double x, double y) {
		var lab = (Gtk.Label)((MWPMarker)mk).get_child();
		var parts = lab.label.split("/");
		if (parts.length == 2) {
			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL,1);
			var plab = new Gtk.Label("# %s".printf(lab.label));
			plab.hexpand = true;
			box.append(plab);
			popno = int.parse(parts[1]);
			popmk = mk;
			var nv = Mwp.gzr.nvertices(nitem);
			MwpMenu.set_menu_state(Mwp.window, "gzdelete", (nv > 3));
			MwpMenu.set_menu_state(Mwp.window, "gzinsert", true);
			pop = new Gtk.PopoverMenu.from_model(menu);
			Gdk.Rectangle rect = { (int)x, (int)y, 1, 1};
			if(n == -1) {
				pop.set_autohide(false);
				var button = new Gtk.Button.from_icon_name("window-close-symbolic");
				button.halign = Gtk.Align.END;
				box.append(button);
				button.clicked.connect(() => {
						pop.popdown();
					});
			} else {
				pop.set_autohide(true);
			}
			pop.add_child(box, "label");
			pop.set_parent(lab);
			pop.set_pointing_to(rect);
			pop.popup();
		}
	}

	public void clear() {
		if (visible) {
			remove_edit_markers(false);
			nitem = 0;
			set_buttons_sensitive();
			init_markers(false);
		}
	}

	public void refresh(Overlay? o) {
		if(visible) {
			ovl = o;
			nitem = 0;
			set_buttons_sensitive();
			edit_markers();
		}
	}
}
