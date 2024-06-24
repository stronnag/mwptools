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

public class SafeHomeMarkers : GLib.Object {
	private Champlain.MarkerLayer safelayer;
	private Champlain.Label []safept;
	private Champlain.PathLayer []safed;
	private Champlain.PathLayer []safel;
	private bool []onscreen;
	private uint16 maxd = 200;
	public signal void safe_move(int idx, double lat, double lon);
	private Clutter.Color scolour;
	private Clutter.Color white;
	public signal void safept_move(int idx, double lat, double lon);
	//	public signal void safept_need_menu(int idx);

	public SafeHomeMarkers(Champlain.View view) {
		scolour.init(0xfb, 0xea, 0x04, 0x68);
		white.init(0xff,0xff,0xff, 0xff);
		onscreen = new bool[SAFEHOMES.maxhomes];
		safept = new  Champlain.Label[SAFEHOMES.maxhomes];
		safed = {};
		safel = {};
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

			var sl = new Champlain.PathLayer();
			sl.set_stroke_width (2);
			sl.set_dash(llist);
			sl.closed = true;
			view.add_layer(sl);
			safel += sl;
		}
	}

	public void set_distance(uint16 d) {
		maxd = d;
	}

	public Champlain.Label get_marker(int j) {
		return safept[j];
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
							Gbl.action = Gbl.POPSOURCE.Safehome;
							Gbl.actor = null;
							Gbl.funcid = idx;
						}
						return true;
					}
					return false;
				});
			onscreen[idx] = true;
		}
		set_safe_colour(idx, h.enabled);
		safept[idx].set_location (h.lat, h.lon);
		update_distance(idx, h);
		FWPlot.update_laylines(idx, safept[idx], h.enabled);
	}

	public void refresh_lay(int idx, SafeHome h) {
		FWPlot.remove_all(idx);
		FWPlot.update_laylines(idx, safept[idx], h.enabled);
	}

	public void update_distance(int idx, SafeHome h) {
		double plat, plon;
		if (maxd > 0) {
			var lp = safed[idx].get_nodes();
			bool upd  = (lp != null && lp.length() > 0);
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
		if (FWPlot.nav_fw_loiter_radius > 0) {
			var lp = safel[idx].get_nodes();
			var upd  = (lp != null && lp.length() > 0);
			var j = 0;
			for (var i = 0; i < 360; i += 5) {
				Geo.posit(h.lat, h.lon, i, FWPlot.nav_fw_loiter_radius/1852.0, out plat, out plon);
				if(upd) {
					lp.nth_data(j).latitude = plat;
					lp.nth_data(j).longitude = plon;
					j++;
				} else {
					var pt = new Champlain.Point();
					pt.latitude = plat;
					pt.longitude = plon;
					safel[idx].add_node(pt);
				}
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
		safel[idx].set_stroke_color(scolour);
		FWPlot.set_colours(idx, state);
	}

	public void hide_safe_home(int idx) {
		if (onscreen[idx]) {
			safelayer.remove_marker(safept[idx]);
			safed[idx].remove_all();
			safel[idx].remove_all();
			FWPlot.remove_all(idx);
		}
		onscreen[idx] = false;
	}
}

public struct SafeHome {
	bool enabled;
	double lat;
	double lon;
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
		<attribute name="label">Load from file</attribute>
		<attribute name="action">dialog.load</attribute>
		</item>
		<item>
		<attribute name="label">Save to file</attribute>
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
				request_safehomes(0, SAFEHOMES.maxhomes);
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
										  typeof (string),
										  typeof (string)
										  );

		Gtk.TreeIter xiter;
		var aref_model = new Gtk.ListStore (2, typeof (string), typeof(bool));
		var dref_model = new Gtk.ListStore (2, typeof (string), typeof(bool));
		aref_model.append (out xiter);
		aref_model.set (xiter, 0, "Rel", 1, false);
		aref_model.append (out xiter);
		aref_model.set (xiter, 0, "AMSL", 1, true);

		Gtk.CellRendererCombo acombo = new Gtk.CellRendererCombo ();
		acombo.set_property ("editable", true);
		acombo.set_property ("model", aref_model);
		acombo.set_property ("text-column", 0);
		acombo.set_property ("has-entry", false);

		dref_model.append (out xiter);
		dref_model.set (xiter, 0, "Left", 1, false);
		dref_model.append (out xiter);
		dref_model.set (xiter, 0, "Right", 1, true);

		Gtk.CellRendererCombo dcombo = new Gtk.CellRendererCombo ();
		dcombo.set_property ("editable", true);
		dcombo.set_property ("model", dref_model);
		dcombo.set_property ("text-column", 0);
		dcombo.set_property ("has-entry", false);

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
		lacell.set_property ("editable", true);
		tview.insert_column_with_attributes (-1, "Latitude", lacell, "text", Column.LAT);
		var col =  tview.get_column(Column.LAT);
		col.set_cell_data_func(lacell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.LAT, out v);
				double val = (double)v;
				string s = PosFormat.lat(val,MWP.conf.dms);
				_cell.set_property("text",s);
			});

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
		locell.set_property ("editable", true);
		tview.insert_column_with_attributes (-1, "Longitude", locell, "text", Column.LON);
		col =  tview.get_column(Column.LON);
		col.set_cell_data_func(locell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.LON, out v);
				double val = (double)v;
				string s = PosFormat.lon(val,MWP.conf.dms);
				_cell.set_property("text",s);
			});

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
		alcell.set_property ("editable", true);
		tview.insert_column_with_attributes (-1, "Land Alt", alcell, "text", Column.LANDALT);
		col =  tview.get_column(Column.LANDALT);
		col.set_cell_data_func(alcell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.LANDALT, out v);
				double val = (double)v;
				string s = "%8.2f".printf(val);
				_cell.set_property("text",s);
			});

		((Gtk.CellRendererText)alcell).edited.connect((path,new_text) => {
				double d = 0.0;
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				if(new_text == "?" || new_text == "@") {
					if(homes[idx].lat != 0.0 && homes[idx].lon != 0.0) {
						var e = MWP.demmgr.lookup(homes[idx].lat, homes[idx].lon);
						if (e != HGT.NODATA)  {
							d = e;
						}
						sh_liststore.set_value (iter, Column.AREF, "Rel");
						FWApproach.set_aref(idx, true);
					}
				} else	{
					d = double.parse(new_text);
				}
				sh_liststore.set_value (iter, Column.LANDALT, d);
				FWApproach.set_landalt(idx, d);
			});

		var aacell = new Gtk.CellRendererText ();
		aacell.set_property ("editable", true);
		tview.insert_column_with_attributes (-1, "Approach Alt", aacell, "text", Column.APPALT);
		col =  tview.get_column(Column.APPALT);
		col.set_cell_data_func(aacell, (col,_cell,model,iter) => {
				GLib.Value v;
				model.get_value(iter, Column.APPALT, out v);
				double val = (double)v;
				string s = "%8.2f".printf(val);
				_cell.set_property("text",s);
			});

		((Gtk.CellRendererText)aacell).edited.connect((path,new_text) => {
				double d;
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				// @+N @-N use landing alt + offset

				if(new_text[0] == '@') {
					d = double.parse(new_text[1:new_text.length]);
					d += FWApproach.get(idx).landalt;
				} else {
					d = double.parse(new_text);
				}
				sh_liststore.set_value (iter, Column.APPALT, d);
				FWApproach.set_appalt(idx, d);
			});

		var d1cell = new Gtk.CellRendererText ();
		d1cell.set_property ("editable", true);
		tview.insert_column_with_attributes (-1, "Direction 1", d1cell, "text", Column.DIRN1);
		col =  tview.get_column(Column.DIRN1);
		((Gtk.CellRendererText)d1cell).edited.connect((path,new_text) => {
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				var dirn1 = (int16)int.parse(new_text);
				sh_liststore.set_value (iter, Column.DIRN1, (int)dirn1);
				FWApproach.set_dirn1(idx, dirn1);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.refresh_lay(idx, homes[idx]);
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
		ex1cell.toggled.connect((t,p) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				//bool ex1 = !FWApproach.get(idx).ex1;
				var ex1 = !t.active;
				FWApproach.set_ex1(idx, ex1);
				sh_liststore.set (iter, Column.EX1, ex1);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.refresh_lay(idx, homes[idx]);
				}
			});

		var d2cell = new Gtk.CellRendererText ();
		d2cell.set_property ("editable", true);

		tview.insert_column_with_attributes (-1, "Direction 2", d2cell, "text", Column.DIRN2);
		col =  tview.get_column(Column.DIRN2);
		((Gtk.CellRendererText)d2cell).edited.connect((path,new_text) => {
				Gtk.TreeIter iter;
				sh_liststore.get_iter (out iter, new Gtk.TreePath.from_string (path));
				int idx = 0;
				sh_liststore.get (iter, Column.ID, &idx);
				var dirn2 = (int16)int.parse(new_text);
				sh_liststore.set_value (iter, Column.DIRN2, (int)dirn2);
				FWApproach.set_dirn2(idx, dirn2);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.refresh_lay(idx, homes[idx]);
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
		ex2cell.toggled.connect((t, p) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				bool ex2 = !t.active;
				FWApproach.set_ex2(idx, ex2);
				sh_liststore.set (iter, Column.EX2, ex2);
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.refresh_lay(idx, homes[idx]);
				}
			});

		tview.insert_column_with_attributes (-1, "Alt. Mode",
											 acombo, "text", Column.AREF);
		acombo.changed.connect((p, citer) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				GLib.Value val;
				aref_model.get_value (citer, 1, out val);
				bool aref = (bool)val;
				//!FWApproach.get(idx).aref;
				FWApproach.set_aref(idx, aref);
				sh_liststore.set (iter, Column.AREF, aref_name(aref));
			});

		tview.insert_column_with_attributes (-1, "Approach",
											 dcombo, "text", Column.DREF);
		dcombo.changed.connect((p, citer) => {
				Gtk.TreeIter iter;
				int idx = 0;
				sh_liststore.get_iter(out iter, new TreePath.from_string(p));
				sh_liststore.get (iter, Column.ID, &idx);
				GLib.Value val;
				dref_model.get_value (citer, 1, out val);
				bool dref = (bool)val;
				FWApproach.set_dref(idx, dref);
				sh_liststore.set (iter, Column.DREF, dref_name(dref));
				if (homes[idx].lat != 0 && homes[idx].lon != 0) {
					shmarkers.refresh_lay(idx, homes[idx]);
				}
			});

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
							  Column.AREF, "Rel",
							  Column.DREF, "Left" );
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
		FWApproach.approach l = {};
		FWApproach.set(idx,l);
		sh_liststore.set (iter,
						  Column.STATUS, false,
						  Column.LAT, 0,
						  Column.LON, 0,
						  Column.APPALT, 0,
						  Column.LANDALT, 0,
						  Column.DIRN1, 0,
						  Column.EX1, false,
						  Column.DIRN2, 0,
						  Column.EX2, false,
						  Column.AREF, aref_name(false),
						  Column.DREF, dref_name(false)
						  );
		shmarkers.hide_safe_home(idx);
	}

	public void set_view(Champlain.View v) {
		view = v;
		FWPlot.init(view);
		shmarkers = new SafeHomeMarkers(v);
		shmarkers.safept_move.connect((idx,la,lo) => {
				homes[idx].lat = la;
				homes[idx].lon = lo;
				FWPlot.update_laylines(idx, shmarkers.get_marker(idx), homes[idx].enabled);
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

	public bool pop_menu(Gdk.Event e) {
		//		if(pop_idx != -1) {
		var idx = Gbl.funcid;
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
		SafeHome hs[8];
		while((s = fs.read_line()) != null) {
            if(s.has_prefix("safehome ")) {
                var parts = s.split_set(" ");
				var idx = int.parse(parts[1]);
				if (idx >= 0 && idx < SAFEHOMES.maxhomes) {
					hs[idx].enabled = (parts[2] == "1") ? true : false;
					hs[idx].lat = double.parse(parts[3]) /10000000.0;
					hs[idx].lon = double.parse(parts[4]) /10000000.0;
				}
			} else if(s.has_prefix("fwapproach ")) {
				var parts = s.split_set(" ");
				var idx = int.parse(parts[1]);
				if (idx >= 0 && idx < FWAPPROACH.maxapproach) {
					FWApproach.approach l={};
					if(parts.length == 8) {
						l.appalt = double.parse(parts[2]) /100.0;
						l.landalt = double.parse(parts[3]) /100.0;
						l.dref = (parts[4] == "1") ? true : false;
						l.dirn1 = (int16)int.parse(parts[5]);
						if(l.dirn1 < 0) {
							l.dirn1 = -l.dirn1;
							l.ex1 = true;
						}
						l.dirn2 = (int16)int.parse(parts[6]);
						if(l.dirn2 < 0) {
							l.dirn2 = -l.dirn2;
							l.ex2 = true;
						}
						l.aref = (parts[7] == "1") ? true : false;
						FWApproach.set(idx, l);
					}
				}
            } else if(s.has_prefix("set ")) {
				int val;
				if (s.contains("nav_fw_land_approach_length")) {
					if (get_set_val(s, out val)) {
						FWPlot.nav_fw_land_approach_length = val/100;
					}
				} else if (s.contains("nav_fw_loiter_radius")) {
					if (get_set_val(s, out val)) {
						FWPlot.nav_fw_loiter_radius = val/100;
					}
				}
			}
        }
		for(var j = 0; j < SAFEHOMES.maxhomes; j++) {
			refresh_home(j, hs[j], true);
		}
    }

	private bool get_set_val(string s, out int val) {
		val=0;
		var n = s.index_of("=");
		if (n != -1) {
			n++;
			if (s[n] == ' ')
				n++;
			val = int.parse(s[n:s.length]);
			return true;
		} else {
			return false;
		}
	}

    private void refresh_home(int idx, SafeHome h, bool forced = false) {
        homes[idx] = h;
		FWApproach.approach lnd = FWApproach.get(idx);

		Gtk.TreeIter iter;
        if(sh_liststore.iter_nth_child (out iter, null, idx))
            sh_liststore.set (iter,
                              Column.STATUS, homes[idx].enabled,
                              Column.LAT, homes[idx].lat,
                              Column.LON, homes[idx].lon,
                              Column.APPALT, lnd.appalt,
							  Column.LANDALT, lnd.landalt,
                              Column.DIRN1, lnd.dirn1,
							  Column.EX1, lnd.ex1,
							  Column.DIRN2, lnd.dirn2,
							  Column.EX2, lnd.ex2,
                              Column.AREF, aref_name(lnd.aref),
                              Column.DREF, dref_name(lnd.dref)
							  );
        if(switcher.active || forced) {
            if(homes[idx].lat != 0 && homes[idx].lon != 0)
                shmarkers.show_safe_home(idx, homes[idx]);
            else
                shmarkers.hide_safe_home(idx);
        }
    }

	private string aref_name(bool a)  {
		return (a) ? "AMSL" : "Rel";
	}

	private string dref_name(bool b)  {
		return (b) ? "Right" : "Left";
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
			sb.append_printf("safehome %d %d %d %d\n", idx, ena,
							 (int)(h.lat*10000000), (int)(h.lon*10000000));
            idx++;
        }

		UpdateFile.save(filename, "safehome", sb.str);

		sb = new StringBuilder();
		for(var j = 0; j < FWAPPROACH.maxapproach; j++) {
			var l = FWApproach.get(j);
			if(l.dirn1 != 0 || l.dirn2 != 0) {
				var aref = (l.aref) ? 1 : 0;
				var dref = (l.dref) ? 1 : 0;
				var d1 = l.dirn1;
				if(l.ex1) {
					d1 = -d1;
				}
				var d2 = l.dirn2;
				if(l.ex2) {
					d2 = -d2;
				}
				sb.append_printf("fwapproach %d %d %d %d %d %d %d\n", j,
								 (int)(l.appalt*100), (int)(l.landalt*100), dref,
								 d1, d2, aref);
			}
		}
		UpdateFile.save(filename, "fwapproach", sb.str);
    }
//current_folder_changed ()
    private void run_chooser(Gtk.FileChooserAction action, Gtk.Window window) {
		var fc = new Acme.FileChooser(action, window, "Safehomes Files");
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

        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Text files");
        filter.add_pattern ("*.txt");
        fc.add_filter (filter);
        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        fc.add_filter (filter);
        fc.run(filename);
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


	/*
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
	*/
