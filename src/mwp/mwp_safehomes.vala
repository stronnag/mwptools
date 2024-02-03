/*
 * Copyright (C) 2018 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public enum SAFEHOMES {
	maxhomes = 8,
}

private const double LAYLEN = (200.0/1852.0);

public class SafeHomeMarkers : GLib.Object {
	private Champlain.MarkerLayer safelayer;
	private Champlain.Label []safept;
	private Champlain.PathLayer []safed;
	private Champlain.PathLayer []lpaths;
	private Champlain.PathLayer []apaths;
	private bool []onscreen;
	private uint16 maxd = 200;
	public signal void safe_move(int idx, double lat, double lon);
	private Clutter.Color scolour;
	private Clutter.Color white;
	private Clutter.Color landcol;
	private Clutter.Color appcol;
	public signal void safept_move(int idx, double lat, double lon);
	//	public signal void safept_need_menu(int idx);

	public SafeHomeMarkers(Champlain.View view) {
		landcol.init(0xfc, 0xac, 0x64, 0xa0);
		appcol.init(0x63, 0xa0, 0xfc, 0xff);
		lpaths = {};
		apaths = {};
		scolour.init(0xfb, 0xea, 0x04, 0x68);
		white.init(0xff,0xff,0xff, 0xff);
		onscreen = new bool[SAFEHOMES.maxhomes];
		safept = new  Champlain.Label[SAFEHOMES.maxhomes];
		safed = {};
		safelayer = new Champlain.MarkerLayer();
		view.add_layer (safelayer);

		var llist = new List<uint>();
		llist.append(5);
		llist.append(5);
		llist.append(5);
		llist.append(5);

		for(var idx = 0; idx < SAFEHOMES.maxhomes; idx++) {
			safept[idx] = new Champlain.Label.with_text ("⏏#%d".printf(idx), "Sans 10",null,null);
			safept[idx].set_alignment (Pango.Alignment.RIGHT);
			safept[idx].set_color (scolour);
			safept[idx].set_text_color(white);

			var sd = new Champlain.PathLayer();
			sd.set_stroke_width (2);
			sd.set_dash(llist);
			sd.closed = true;
			view.add_layer(sd);
			safed += sd;
			var l0 = new Champlain.PathLayer();
			l0.set_stroke_width (3);
			l0.set_stroke_color(landcol);
			var l1 = new Champlain.PathLayer();
			l1.set_stroke_width (3);
			l1.set_stroke_color(landcol);
			view.add_layer(l0);
			view.add_layer(l1);
			lpaths += l0;
			lpaths += l1;

			var a0 = new Champlain.PathLayer();
			a0.set_stroke_width (3);
			a0.set_stroke_color(appcol);
			a0.set_dash(llist);
			var a1 = new Champlain.PathLayer();
			a1.set_stroke_width (3);
			a1.set_stroke_color(appcol);
			a1.set_dash(llist);
			view.add_layer(a0);
			view.add_layer(a1);
			apaths += a0;
			apaths += a1;
		}
	}

	public void set_distance(uint16 d) {
		maxd = d;
	}

	private Champlain.Point set_laypoint(int dirn, double lat, double lon, double dlen=LAYLEN) {
		double dlat, dlon;
		Geo.posit(lat, lon, dirn, dlen, out dlat, out dlon);
		var ip0 =  new	Champlain.Point();
		ip0.latitude = dlat;
		ip0.longitude = dlon;
		return ip0;
	}

	public void update_laylines(int idx, SafeHome h) {
		Champlain.Location ip0;
		Champlain.Location ip1;
		int pi = idx*2;
		landcol.alpha = (h.enabled) ? 0xa0 : 0x60;
		appcol.alpha = (h.enabled) ? 0xff : 0x80;
		if(h.dirn1 != 0) {
			var pts = lpaths[pi].get_nodes();
			bool upd = (pts != null && pts.length() > 0);
			if(h.ex1) {
				ip0 = safept[idx];
			} else {
				ip0 =  set_laypoint(h.dirn1, h.lat, h.lon);
			}
			if (upd) {
				pts.nth_data(0).latitude = ip0.latitude;
				pts.nth_data(0).longitude = ip0.longitude;
			} else {
				lpaths[pi].add_node(ip0);
			}
			var adir = (h.dirn1 + 180) % 360;
			ip1 =  set_laypoint(adir, h.lat, h.lon);
			if (upd) {
				pts.nth_data(1).latitude = ip1.latitude;
				pts.nth_data(1).longitude = ip1.longitude;
			} else {
				lpaths[pi].add_node(ip1);
			}
			add_approach(idx, pi, h.dirn1, h.ex1, h.dref, ip0, ip1);
		}

		pi++;

		if(h.dirn2 != 0) {
			var pts = lpaths[pi].get_nodes();
			bool upd = (pts != null && pts.length() > 0);
			if(h.ex2) {
				ip0 = safept[idx];
			} else {
				ip0 =  set_laypoint(h.dirn2, h.lat, h.lon);
			}
			if(upd) {
				pts.nth_data(0).latitude = ip0.latitude;
				pts.nth_data(0).longitude = ip0.longitude;
			} else {
				lpaths[pi].add_node(ip0);
			}
			var adir = (h.dirn2 + 180) % 360;
			ip1 =  set_laypoint(adir, h.lat, h.lon);
			if(upd) {
				pts.nth_data(1).latitude = ip1.latitude;
				pts.nth_data(1).longitude = ip1.longitude;
			} else {
				lpaths[pi].add_node(ip1);
			}
			add_approach(idx, pi, h.dirn2, h.ex2, h.dref, ip0, ip1);
		}
	}

	private void add_approach(int idx, int pi, int dirn, bool ex, bool dref,
							  Champlain.Location ip0, Champlain.Location ip1) {
		apaths[pi].remove_all(); // number of nodes will change if exclusive changed ..
		int xdir= dirn;
			if(dref)
				xdir += 90;
			else
				xdir -= 90;
			xdir %= 360;
			var ipx =  set_laypoint(xdir, ip1.latitude, ip1.longitude, LAYLEN/3);
			apaths[pi].add_node(ip1);
			apaths[pi].add_node(ipx);
			if(ex) {
				apaths[pi].add_node(ip0);
			} else {
				apaths[pi].add_node(safept[idx]);
				ipx =  set_laypoint(xdir, ip0.latitude, ip0.longitude, LAYLEN/3);
				apaths[pi].add_node(ipx);
				apaths[pi].add_node(ip0);
			}
	}

	public void show_safe_home(int idx, SafeHome h) {
		if(onscreen[idx] == false) {
			safept[idx].set_flags(ActorFlags.REACTIVE);
			safelayer.add_marker(safept[idx]);
			safept[idx].drag_motion.connect((dx,dy,evt) => {
					safept_move(idx, safept[idx].get_latitude(), safept[idx].get_longitude());
				});
			safept[idx].button_press_event.connect((e) => {
					if(e.button == 3) {
						if (safept[idx].draggable) {
							var p = MWP.ViewPop();
							p.id = MWP.POPSOURCE.Safehome;
							p.mk = null;
							p.funcid = idx;
							MWP.popqueue.push(p);
						}
					}
					return false;
				});
			onscreen[idx] = true;
		}
		set_safe_colour(idx, h.enabled);
		safept[idx].set_location (h.lat, h.lon);
		update_distance(idx, h);
		update_laylines(idx, h);
	}

	public void update_distance(int idx, SafeHome h) {
		var lp = safed[idx].get_nodes();
		bool upd  = (lp != null && lp.length() > 0);
		double plat, plon;
		var j = 0;
		for (var i = 0; i < 360; i += 5) {
			Geo.posit(h.lat, h.lon, i, maxd/1852.0, out plat, out plon);
			if(upd) {
				lp.nth_data(j).latitude = plat;
				lp.nth_data(j).longitude = plon;
				j++;
			} else {
				var pt = new Champlain.Point();
				pt.latitude = plat;
				pt.longitude = plon;
				safed[idx].add_node(pt);
			}
		}
	}

	public void set_interactive(bool state) {
		for(var i = 0; i < SAFEHOMES.maxhomes; i++) {
			safept[i].set_draggable(state);
		}
	}

	public void set_safe_colour(int idx, bool state) {
		scolour.alpha = (state) ? 0xc8 : 0x68;
		safept[idx].set_color (scolour);
		safed[idx].set_stroke_color(scolour);

		int pi = idx*2;
		landcol.alpha = (state) ? 0xa0 : 0x60;
		appcol.alpha = (state) ? 0xff : 0x80;

		for(var j = 0; j < 2; j++) {
			lpaths[pi+j].set_stroke_color(landcol);
			apaths[pi+j].set_stroke_color(appcol);
		}
	}

	public void hide_safe_home(int idx) {
		if (onscreen[idx]) {
			safelayer.remove_marker(safept[idx]);
			safed[idx].remove_all();
			int pi = 2*idx;
			lpaths[pi].remove_all();
			apaths[pi].remove_all();
			pi += 1;
			lpaths[pi].remove_all();
			apaths[pi].remove_all();
		}
		onscreen[idx] = false;
	}
}

public struct SafeHome {
	bool enabled;
	double lat;
	double lon;
	double appalt;
	double landalt;
	int dirn1;
	bool ex1;
	int dirn2;
	bool ex2;
	bool aref;
	bool dref;
}

public class  SafeHomeDialog : Window {
	private string filename;
	private Gtk.ListStore sh_liststore;
	private bool available = false;
	private Champlain.View view;
	//	private int pop_idx = -1;
	private Gtk.Switch switcher;
	private GLib.SimpleAction aq_fcl;
	private GLib.SimpleAction aq_fcs;

	public signal void request_safehomes(uint8 first, uint8 last);
	public signal void notify_publish_request();

	enum Column {
		ID,
		STATUS,
		LAT,
		LON,
		LANDALT,
		APPALT,
		DIRN1,
		EX1,
		DIRN2,
		EX2,
		AREF,
		DREF,
		NO_COLS
	}

	private SafeHome []homes;
	private SafeHomeMarkers shmarkers;

	public SafeHomeDialog(Gtk.Window _w) {
		var xml = """
		<?xml version="1.0" encoding="UTF-8"?>
		<interface>
		<menu id="app-menu">
		<section>
		<item>
		<attribute name="label">Load safehome file</attribute>
		<attribute name="action">dialog.load</attribute>
		</item>
		<item>
		<attribute name="label">Save safehome file</attribute>
		<attribute name="action">dialog.save</attribute>
		</item>
		</section>
		<section>
		<item>
		<attribute name="label">Load from FC</attribute>
		<attribute name="action">dialog.loadfc</attribute>
		</item>
		<item>
		<attribute name="label">Save to FC</attribute>
		<attribute name="action">dialog.savefc</attribute>
		</item>
		</section>
		</menu>
		</interface>
		""";

		homes = new SafeHome[SAFEHOMES.maxhomes];
		filename = "None";

		set_transient_for(_w);

		var fsmenu_button = new Gtk.MenuButton();
		Gtk.Image img = new Gtk.Image.from_icon_name("open-menu-symbolic",
													 Gtk.IconSize.BUTTON);
		var childs = fsmenu_button.get_children();
		fsmenu_button.remove(childs.nth_data(0));
		fsmenu_button.add(img);
		var header_bar = new Gtk.HeaderBar ();
		header_bar.set_title ("Safehomes Manager");
		//		headervbar.set_decoration_layout(":close");
		header_bar.show_close_button = true;
		header_bar.pack_start (fsmenu_button);
		header_bar.has_subtitle = false;
		switcher =	new Gtk.Switch();
		header_bar.pack_end (switcher);
		header_bar.pack_end (new Gtk.Label("Persistent map display"));
		set_titlebar (header_bar);


		/*
  This does not affec the edit display, just the permanence
  switcher.notify["active"].connect (() => {
  var state = switcher.get_active();
  display_homes(state);
  });
*/
		var sbuilder = new Gtk.Builder.from_string(xml, -1);
		var menu = sbuilder.get_object("app-menu") as GLib.MenuModel;
		var pop = new Gtk.Popover.from_model(fsmenu_button, menu);
		fsmenu_button.set_popover(pop);
		fsmenu_button.set_use_popover(false);

		var dg = new GLib.SimpleActionGroup();

		var aq = new GLib.SimpleAction("load",null);
		aq.activate.connect(() => {
				run_chooser( Gtk.FileChooserAction.OPEN, _w);
			});
		dg.add_action(aq);

		aq = new GLib.SimpleAction("save",null);
		aq.activate.connect(() => {
				run_chooser( Gtk.FileChooserAction.SAVE, _w);
			});
		dg.add_action(aq);

		aq_fcl = new GLib.SimpleAction("loadfc",null);
		aq_fcl.activate.connect(() => {
				request_safehomes(0, 7);
			});
		aq_fcl.set_enabled(false);
		dg.add_action(aq_fcl);

		aq_fcs = new GLib.SimpleAction("savefc",null);
		aq_fcs.activate.connect(() => {
				notify_publish_request();
			});
		aq_fcs.set_enabled(false);
		dg.add_action(aq_fcs);

		this.insert_action_group("dialog", dg);
		this.delete_event.connect (() => {
				hide_action();
				return true;
			});

		var tview = new Gtk.TreeView ();
		tview.button_press_event.connect( (event) => {
				if(event.button == 3) {
					var sel = tview.get_selection ();
					if(sel.count_selected_rows () == 1) {
						var rows = sel.get_selected_rows(null);
						Gtk.TreeIter iter;
						sh_liststore.get_iter (out iter, rows.nth_data(0));
						row_menu(event, iter);
					}
					return true;
				}
				return false;
			});

		sh_liststore = new Gtk.ListStore (Column.NO_COLS,
										  typeof (int),
										  typeof (bool),
										  typeof (double),
										  typeof (double),
										  typeof (double),
										  typeof (double),
										  typeof (int),
										  typeof (bool),
										  typeof (int),
										  typeof (bool),
										  typeof (bool),
										  typeof (bool)
										  );

		tview.set_model (sh_liststore);
		tview.insert_column_with_attributes (-1, "Id",
											new Gtk.CellRendererText (), "text",
											Column.ID);

		var cell = new Gtk.CellRendererToggle();
		tview.insert_column_with_attributes (-1, "Enabled",
											 cell, "active", Column.STATUS);
		cell.toggled.connect((p) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].enabled = !homes[idx].enabled;
				sh_liststore.set (iter, Column.STATUS, homes[idx].enabled);
				if(homes[idx].enabled) {
					if (homes[idx].lat == 0 && homes[idx].lon == 0) {
						set_default_loc(idx);
						sh_liststore.set (iter,
										  Column.LAT, homes[idx].lat,
										  Column.LON, homes[idx].lon);
					}
					shmarkers.show_safe_home(idx, homes[idx]);
				} else {
					shmarkers.set_safe_colour(idx, false);
				}
			});

		var lacell = new Gtk.CellRendererText ();
		tview.insert_column_with_attributes (-1, "Latitude", lacell, "text", Column.LAT);
		var col =  tview.get_column(Column.LAT);
		col.set_cell_data_func(lacell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.LAT, out v);
				double val = (double)v;
				string s = PosFormat.lat(val,MWP.conf.dms);
				_cell.set_property("text",s);
			});

		lacell.set_property ("editable", true);
		((Gtk.CellRendererText)lacell).edited.connect((path,new_text) => {
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].lat = InputParser.get_latitude(new_text);
				sh_liststore.set_value (iter, Column.LAT, homes[idx].lat);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.show_safe_home(idx, homes[idx]);
				}
			});

		var locell = new Gtk.CellRendererText ();
		tview.insert_column_with_attributes (-1, "Longitude", locell, "text", Column.LON);
		col =  tview.get_column(Column.LON);
		col.set_cell_data_func(locell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.LON, out v);
				double val = (double)v;
				string s = PosFormat.lon(val,MWP.conf.dms);
				_cell.set_property("text",s);
			});

		locell.set_property ("editable", true);
		((Gtk.CellRendererText)locell).edited.connect((path,new_text) => {
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].lon = InputParser.get_longitude(new_text);
				sh_liststore.set_value (iter, Column.LON, homes[idx].lon);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.show_safe_home(idx, homes[idx]);
				}
			});

		var alcell = new Gtk.CellRendererText ();
		tview.insert_column_with_attributes (-1, "Land Alt", alcell, "text", Column.LANDALT);
		col =  tview.get_column(Column.LANDALT);
		col.set_cell_data_func(alcell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.LANDALT, out v);
				double val = (double)v;
				string s = "%8.2f".printf(val);
				_cell.set_property("text",s);
			});
		alcell.set_property ("editable", true);
		((Gtk.CellRendererText)alcell).edited.connect((path,new_text) => {
				double d = 0.0;
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				if(new_text == "?") {
					if(homes[idx].lat != 0.0 && homes[idx].lon != 0.0) {
						var e = MWP.demmgr.lookup(homes[idx].lat, homes[idx].lon);
						if (e != HGT.NODATA)  {
							d = e;
						}
						sh_liststore.set_value (iter, Column.AREF, true);
						homes[idx].aref = true;
					}
				} else	{
					d = double.parse(new_text);
				}
				sh_liststore.set_value (iter, Column.LANDALT, d);
				homes[idx].landalt = d;
			});

		var aacell = new Gtk.CellRendererText ();
		tview.insert_column_with_attributes (-1, "Approach Alt", aacell, "text", Column.APPALT);
		col =  tview.get_column(Column.APPALT);
		col.set_cell_data_func(aacell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.APPALT, out v);
				double val = (double)v;
				string s = "%8.2f".printf(val);
				_cell.set_property("text",s);
			});
		aacell.set_property ("editable", true);
		((Gtk.CellRendererText)aacell).edited.connect((path,new_text) => {
				double d;
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				// @+N @-N use landing alt + offset

				if(new_text[0] == '@') {
					d = double.parse(new_text[1:new_text.length]);
					stderr.printf("DBG: newtext %s d=%f la=%f\n", new_text, d, homes[idx].landalt);
					d += homes[idx].landalt;
				} else {
					d = double.parse(new_text);
				}
				sh_liststore.set_value (iter, Column.APPALT, d);
				homes[idx].appalt = d;
			});

		var d1cell = new Gtk.CellRendererText ();
		tview.insert_column_with_attributes (-1, "Direction 1", d1cell, "text", Column.DIRN1);
		col =  tview.get_column(Column.DIRN1);
		d1cell.set_property ("editable", true);
		((Gtk.CellRendererText)d1cell).edited.connect((path,new_text) => {
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].dirn1 = int.parse(new_text);
				sh_liststore.set_value (iter, Column.DIRN1, homes[idx].dirn1);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.show_safe_home(idx, homes[idx]);
				}
			});

		col.set_cell_data_func(d1cell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.DIRN1, out v);
				int val = (int)v;
				if (val < -2 || val > 360)
					val = 0;
				string s = "%4d".printf(val);
				_cell.set_property("text",s);
			});


		var ex1cell = new Gtk.CellRendererToggle();
		tview.insert_column_with_attributes (-1, "Exc1",
											 ex1cell, "active", Column.EX1);
		ex1cell.toggled.connect((p) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].ex1 = !homes[idx].ex1;
				sh_liststore.set (iter, Column.EX1, homes[idx].ex1);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.show_safe_home(idx, homes[idx]);
				}
			});

		var d2cell = new Gtk.CellRendererText ();
		tview.insert_column_with_attributes (-1, "Direction 2", d2cell, "text", Column.DIRN2);
		col =  tview.get_column(Column.DIRN2);
		d2cell.set_property ("editable", true);
		((Gtk.CellRendererText)d2cell).edited.connect((path,new_text) => {
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].dirn2 = int.parse(new_text);
				sh_liststore.set_value (iter, Column.DIRN2, homes[idx].dirn2);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.show_safe_home(idx, homes[idx]);
				}
			});
		col.set_cell_data_func(d2cell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.DIRN2, out v);
				int val = (int)v;
				if (val < -2 || val > 360)
					val = 0;
				string s = "%4d".printf(val);
				_cell.set_property("text",s);
			});

		var ex2cell = new Gtk.CellRendererToggle();
		tview.insert_column_with_attributes (-1, "Exc2",
											 ex2cell, "active", Column.EX2);
		ex2cell.toggled.connect((p) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].ex2 = !homes[idx].ex2;
				sh_liststore.set (iter, Column.EX2, homes[idx].ex2);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.show_safe_home(idx, homes[idx]);
				}
			});


		var arcell = new Gtk.CellRendererToggle();
		tview.insert_column_with_attributes (-1, "Alt AMSL",
											 arcell, "active", Column.AREF);
		arcell.toggled.connect((p) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].aref = !homes[idx].aref;
				sh_liststore.set (iter, Column.AREF, homes[idx].aref);
			});

		var drcell = new Gtk.CellRendererToggle();
		tview.insert_column_with_attributes (-1, "Approach Right",
											 drcell, "active", Column.DREF);
		drcell.toggled.connect((p) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				homes[idx].dref = !homes[idx].dref;
				sh_liststore.set (iter, Column.DREF, homes[idx].dref);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.show_safe_home(idx, homes[idx]);
				}
			});

		/*
		DIRN1,
		DIRN2,
		AREF,
		DREF,
		*/

		var vbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
		vbox.pack_start (tview, false, false, 0);

		Gtk.TreeIter iter;
		for(var i = 0; i < SAFEHOMES.maxhomes; i++) {
			sh_liststore.append (out iter);
			sh_liststore.set (iter,
							  Column.ID, i,
							  Column.STATUS, false,
							  Column.LAT, 0.0,
							  Column.LON, 0.0,
							  Column.APPALT, 0.0,
							  Column.LANDALT, 0.0,
							  Column.DIRN1, 0,
							  Column.EX1, false,
							  Column.DIRN2, 0,
							  Column.EX2, false,
							  Column.AREF, false,
							  Column.DREF, false
							  );
		}
		add(vbox);
	}

	public void remove_homes() {
		display_homes(false);
	}

	private void hide_action() {
		available = false;
		shmarkers.set_interactive(false);
		var state = switcher.get_active();
		if(!state)
			display_homes(false);
		hide();
	}

	public void online_change(uint32 v) {
		var sens = (v >= MWP.FCVERS.hasSAFEAPI); //.0x020700
		aq_fcs.set_enabled(sens);
		aq_fcl.set_enabled(sens);
	}

	public SafeHome get_home(uint8 idx) {
		return homes[idx];
	}

	private void row_menu(Gdk.EventButton e, Gtk.TreeIter iter) {
		var idx = 0;
		sh_liststore.get (iter, Column.ID, &idx);
		var marker_menu = new Gtk.Menu ();
		var item = new Gtk.MenuItem.with_label ("Centre On");
		item.activate.connect (() => {
				double lat,lon;
				sh_liststore.get (iter, Column.LAT, out lat);
				sh_liststore.get (iter, Column.LON, out lon);
				if(lat != 0 && lon != 0)
					view.center_on(lat, lon);
			});
		marker_menu.add (item);
		item = new Gtk.MenuItem.with_label ("Clear Item");
		item.activate.connect (() => {
				clear_item(idx,iter);
			});
		marker_menu.add (item);
		item = new Gtk.MenuItem.with_label ("Clear All");
		item.activate.connect (() => {
				for(var i = 0; i < SAFEHOMES.maxhomes; i++)
					if(sh_liststore.iter_nth_child (out iter, null, i))
						clear_item(i, iter);
			});
		marker_menu.add (item);
		marker_menu.show_all();
		marker_menu.popup_at_pointer(e);
	}
		/*
	private void set_menu_state(string action, bool state) {
		var ac = window.lookup_action(action) as SimpleAction;
		ac.set_enabled(state);
	}
		*/
	public void receive_safehome(uint8 idx, SafeHome shm) {
		refresh_home(idx,  shm);
	}

	private void clear_item(int idx, Gtk.TreeIter iter) {
		homes[idx] = {};
		sh_liststore.set (iter,
						  Column.STATUS, homes[idx].enabled,
						  Column.LAT, homes[idx].lat,
						  Column.LON, homes[idx].lon,
						  Column.APPALT, homes[idx].appalt,
						  Column.LANDALT, homes[idx].landalt,
						  Column.DIRN1, homes[idx].dirn1,
						  Column.EX1, homes[idx].ex1,
						  Column.DIRN2, homes[idx].dirn2,
						  Column.EX2, homes[idx].ex2,
						  Column.AREF, homes[idx].aref,
						  Column.DREF, homes[idx].dref
						  );
		shmarkers.hide_safe_home(idx);
	}

	public void set_view(Champlain.View v) {
		view = v;
		shmarkers = new SafeHomeMarkers(v);
		shmarkers.safept_move.connect((idx,la,lo) => {
			homes[idx].lat = la;
			homes[idx].lon = lo;
			shmarkers.update_laylines(idx, homes[idx]);
			shmarkers.update_distance(idx, homes[idx]);
			Gtk.TreeIter iter;
			if(sh_liststore.iter_nth_child (out iter, null, idx))
				sh_liststore.set (iter,
								  Column.LAT, homes[idx].lat,
								  Column.LON, homes[idx].lon);
			});
		//		shmarkers.safept_need_menu.connect((idx) => {
		//		pop_idx = idx;
		//	});
	}

	public void set_distance(uint16 d) {
		shmarkers.set_distance(d);
	}

	public bool pop_menu(Gdk.EventButton e, MWP.ViewPop vp) {
		//		if(pop_idx != -1) {
		var idx = vp.funcid;
		var marker_menu = new Gtk.Menu ();
		var item = new Gtk.MenuItem.with_label ("Toggle State");
		item.activate.connect (() => {
				homes[idx].enabled = ! homes[idx].enabled;
				Gtk.TreeIter iter;
				if(sh_liststore.iter_nth_child (out iter, null, idx))
					sh_liststore.set (iter,
									  Column.STATUS, homes[idx].enabled);
				shmarkers.set_safe_colour(idx, homes[idx].enabled);
			});
		marker_menu.add (item);
		item = new Gtk.MenuItem.with_label ("Clear Item");
		item.activate.connect (() => {
				homes[idx].enabled = false;
				homes[idx].lat = 0;
				homes[idx].lon = 0;
				Gtk.TreeIter iter;
				if(sh_liststore.iter_nth_child (out iter, null, idx))
					sh_liststore.set (iter,
									  Column.STATUS, homes[idx].enabled,
									  Column.LAT, homes[idx].lat,
									  Column.LON, homes[idx].lon);
				shmarkers.hide_safe_home(idx);
			});
		marker_menu.add (item);
		marker_menu.show_all();
		marker_menu.popup_at_pointer(e);
		//pop_idx = -1;
		return true;
	}
	//return false;
    //}

    private void set_default_loc(int idx) {
        homes[idx].lat = view.get_center_latitude();
        homes[idx].lon = view.get_center_longitude();
    }

    private void read_file() {
        FileStream fs = FileStream.open (filename, "r");
        if(fs == null) {
            return;
        }
        string s;
        while((s = fs.read_line()) != null) {
            if(s.has_prefix("safehome ")) {
                var parts = s.split_set(" ");
				if(parts.length >= 5) {
					SafeHome h = {};
					var idx = int.parse(parts[1]);
					if (idx >= 0 && idx < SAFEHOMES.maxhomes) {
						h.enabled = (parts[2] == "1") ? true : false;
						h.lat = double.parse(parts[3]) /10000000.0;
						h.lon = double.parse(parts[4]) /10000000.0;
						if(parts.length == 11) {
							h.appalt = double.parse(parts[5]) /100.0;
							h.landalt = double.parse(parts[6]) /100.0;
							h.dirn1 = int.parse(parts[7]);
							if(h.dirn1 < 0) {
								h.dirn1 = -h.dirn1;
								h.ex1 = true;
							}
							h.dirn2 = int.parse(parts[8]);
							if(h.dirn2 < 0) {
								h.dirn2 = -h.dirn2;
								h.ex2 = true;
							}
							h.aref = (parts[9] == "1") ? true : false;
							h.dref = (parts[10] == "1") ? true : false;
						}
						refresh_home(idx, h);
					}
				}
            }
        }
    }

    private void refresh_home(int idx, SafeHome h) {
        homes[idx] = h;
        Gtk.TreeIter iter;
        if(sh_liststore.iter_nth_child (out iter, null, idx))
            sh_liststore.set (iter,
                              Column.STATUS, homes[idx].enabled,
                              Column.LAT, homes[idx].lat,
                              Column.LON, homes[idx].lon,
                              Column.APPALT, homes[idx].appalt,
							  Column.LANDALT, homes[idx].landalt,
                              Column.DIRN1, homes[idx].dirn1,
							  Column.EX1, homes[idx].ex1,
							  Column.DIRN2, homes[idx].dirn2,
							  Column.EX2, homes[idx].ex2,
                              Column.AREF, homes[idx].aref,
                              Column.DREF, homes[idx].dref
							  );
        if(switcher.active) {
            if(homes[idx].lat != 0 && homes[idx].lon != 0)
                shmarkers.show_safe_home(idx, homes[idx]);
            else
                shmarkers.hide_safe_home(idx);
        }
    }

    private void display_homes(bool state) {
        for (var idx = 0; idx < SAFEHOMES.maxhomes; idx++) {
            if(state) {
                if(homes[idx].lat != 0 && homes[idx].lon != 0) {
                    shmarkers.show_safe_home(idx, homes[idx]);
                }
            } else
                shmarkers.hide_safe_home(idx);
        }
    }

    public void load_homes(string fn, bool disp) {
        filename = fn;
        read_file();
		set_status(disp);
    }

	public void set_status(bool disp) {
        if (disp) {
            display_homes(true);
            switcher.set_active(true);
        }
	}

    private void save_file() {
		StringBuilder sb = new StringBuilder();
        var idx = 0;
        foreach (var h in homes) {
			var ena = (h.enabled) ? 1 : 0;
			var aref = (h.aref) ? 1 : 0;
			var dref = (h.dref) ? 1 : 0;
			if(h.ex1) {
				h.dirn1 = -h.dirn1;
			}
			if(h.ex2) {
				h.dirn2 = -h.dirn2;
			}
			sb.append_printf("safehome %d %d %d %d %d %d %d %d %d %d\n", idx, ena,
                      (int)(h.lat*10000000), (int)(h.lon*10000000),
					  (int)(h.appalt*100), (int)(h.landalt*100),
					  h.dirn1, h.dirn2, aref, dref);
            idx++;
        }
		UpdateFile.save(filename, "safehome", sb.str);
    }
//current_folder_changed ()
    private void run_chooser(Gtk.FileChooserAction action, Gtk.Window window) {
        Gtk.FileChooserDialog fc = new Gtk.FileChooserDialog (
            "Safehome definition",
            window, action,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            (action == Gtk.FileChooserAction.SAVE) ? "_Save" : "_Open",
            Gtk.ResponseType.ACCEPT);

        fc.select_multiple = false;

        if(action == Gtk.FileChooserAction.SAVE && filename != null)
            fc.set_filename(filename);

        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Text files");
        filter.add_pattern ("*.txt");
        fc.add_filter (filter);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        fc.add_filter (filter);

        fc.response.connect((result) => {
                if (result== Gtk.ResponseType.ACCEPT) {
                    filename  = fc.get_file().get_path ();
                    if (action == Gtk.FileChooserAction.OPEN) {
                        load_homes(filename, switcher.active);
                    }
                    else if (result == Gtk.ResponseType.ACCEPT) {
                        save_file();
                    }
                }
                fc.close();
                fc.destroy();
            });
        fc.show();
    }

    public void display() {
        if(!available) {
			available = true;
            show_all ();
            shmarkers.set_interactive(true);
			var state = switcher.get_active();
			if(!state)
				display_homes(true);
		}
    }
}
