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

public enum SAFEHOMES {
	maxhomes = 8,
}

namespace Safehome {
	public SafeHomeDialog manager;
}

namespace SHPop {
	int idx;
	GLib.MenuModel mmodel;
}

public class SafeHomeMarkers : GLib.Object {
	private MWPLabel []safept;
	private Shumate.PathLayer []safed;
	private Shumate.PathLayer []safel;
	private Shumate.MarkerLayer safelayer;
	private bool []onscreen;
	private uint16 maxd = 200;
	public signal void safe_move(int idx, double lat, double lon);
	private Gdk.RGBA scolour;
	private Gdk.RGBA white;
	public signal void safept_move(int idx, double lat, double lon);
	//	public signal void safept_need_menu(int idx);

	public SafeHomeMarkers() {
		scolour.parse("rgba(0xfb, 0xea, 0x04, 0.4)");
		white.parse("white");
		onscreen = new bool[SAFEHOMES.maxhomes];
		safept = new  MWPLabel[SAFEHOMES.maxhomes];
		safed = {};
		safel = {};
		safelayer = new Shumate.MarkerLayer(Gis.map.viewport);
		Gis.map.insert_layer_behind (safelayer, Gis.mm_layer); // below mission path
		var llist = new List<uint>();
		llist.append(5);
		llist.append(5);
		llist.append(5);
		llist.append(5);

		for(var idx = 0; idx < SAFEHOMES.maxhomes; idx++) {
			safept[idx] = new MWPLabel("⏏#%d".printf(idx));
			safept[idx].set_colour (scolour.to_string());
			safept[idx].set_text_colour("black");
			safept[idx].set_draggable(true);
			safept[idx].no = idx;
			var sd = new Shumate.PathLayer(Gis.map.viewport);
			sd.set_stroke_width (2);
			sd.set_dash(llist);
			sd.closed = true;
			Gis.map.insert_layer_behind (sd, Gis.mp_layer); // below mission path
			safed += sd;

			var sl = new Shumate.PathLayer(Gis.map.viewport);
			sl.set_stroke_width (2);
			sl.set_dash(llist);
			sl.closed = true;
			Gis.map.insert_layer_behind (sl, Gis.mp_layer); // below mission path
			safel += sl;
		}
	}

	public void set_distance(uint16 d) {
		maxd = d;
	}

	public MWPLabel get_marker(int j) {
		return safept[j];
	}

	public void show_safe_home(int idx, SafeHome h) {
		if(onscreen[idx] == false) {
			safelayer.add_marker(safept[idx]);
			safept[idx].drag_motion.connect((la,lo) => {
					safept_move(idx, la, lo);
				});

			safept[idx].popup_request.connect(( n, x, y) => {
					SHPop.idx = idx;
					var popup = new Gtk.PopoverMenu.from_model(SHPop.mmodel);
					popup.set_has_arrow(true);
					popup.set_autohide(true);
					popup.set_parent(safept[idx]);
					popup.popup();
				});
			onscreen[idx] = true;
		}
		set_safe_colour(idx, h.enabled);
		safept[idx].latitude = h.lat;
		safept[idx].longitude = h.lon;
		// ** ICI **/
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
					var pt = new Shumate.Marker();
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
					var pt = new Shumate.Marker();
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
		scolour.alpha = (state) ? 0.78f : 0.4f;
		safept[idx].set_colour (scolour);
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

public class SafeHome : Object {
	public int id {get; construct set;}
	public bool enabled  {get; construct set;}
	public double lat {get; construct set;}
	public double lon {get; construct set;}
	public double appalt {get; construct set;}
    public double landalt {get; construct set;}
    public int16 dirn1 {get; construct set;}
    public int16 dirn2 {get; construct set;}
    public bool ex1 {get; construct set;}
    public bool ex2 {get; construct set;}
    public bool aref {get; construct set;}
    public bool dref {get; construct set;}
}

internal enum Column {
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

public class  SafeHomeDialog : Adw.Window {
	private bool _available = false;
	private string filename;
	private GLib.ListStore lstore;
	private Gtk.ColumnView cv;
	Gtk.SingleSelection lsel;
    Gtk.ColumnViewColumn cols[Colums.NO_COLS];

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

	private SafeHomeMarkers shmarkers;

	public SafeHomeDialog() {
		filename = "None";
		title = "Safehomes Manager";
		set_transient_for(Mwp.window);
		var sbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);

		var header_bar = new Adw.HeaderBar();
		var fsmenu_button = new Gtk.MenuButton();
		fsmenu_button.icon_name = "open-menu-symbolic";
		header_bar.pack_start (fsmenu_button);
		switcher =	new Gtk.Switch();
		header_bar.pack_end (switcher);
		header_bar.pack_end (new Gtk.Label("Persistent map display"));
		sbox.append(header_bar);

		var sbuilder = new Gtk.Builder.from_resource ("/org/stronnag/mwp/safehmenu.ui");
		SHPop.mmodel = sbuilder.get_object("shpop-menu") as GLib.MenuModel;
		var shmenu = sbuilder.get_object("sh-menu") as GLib.MenuModel;
		var shpop = new Gtk.PopoverMenu.from_model(shmenu);
		fsmenu_button.set_popover(shpop);

		var dg = new GLib.SimpleActionGroup();
		var aq = new GLib.SimpleAction("load",null);
		aq.activate.connect(() => {
				run_chooser( Gtk.FileChooserAction.OPEN);
			});
		dg.add_action(aq);

		aq = new GLib.SimpleAction("save",null);
		aq.activate.connect(() => {
				run_chooser( Gtk.FileChooserAction.SAVE);
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

		var dgm = new GLib.SimpleActionGroup();
		var maq = new GLib.SimpleAction("centre",null);
		maq.activate.connect(() => {
				mcentre_on();
			});
		dgm.add_action(maq);
		maq = new GLib.SimpleAction("toggle",null);
		maq.activate.connect(() => {
				mtoggle_item();
			});
		dgm.add_action(maq);
		maq = new GLib.SimpleAction("clear",null);
		maq.activate.connect(() => {
				mclear_item();
			});
		dgm.add_action(maq);
		maq = new GLib.SimpleAction("clearall",null);
		maq.activate.connect(() => {
				mclear_allitems();
			});
		dgm.add_action(maq);

		this.insert_action_group("sh", dg);
		Mwp.window.insert_action_group("shm", dgm);

		this.close_request.connect (() => {
				hide_action();
				return true;
			});

		create_cv();
		sbox.margin_start = 8;
		sbox.margin_end = 8;

		sbox.append (tview);

		shmarkers = new SafeHomeMarkers();
		shmarkers.safept_move.connect((idx,la,lo) => {
				drag_action(idx, la, lo);
			});
		set_content(sbox);
	}

	private void create_cv() {
		lstore = new GLib.ListStore(typeof(SafeHome));
		var sm = new Gtk.SortListModel(lstore, cv.sorter);
		lsel = new Gtk.SingleSelection(sm);
		cv.set_model(lsel);
		cv.show_column_separators = true;
		cv.show_row_separators = true;

        var f0 = new Gtk.SignalListItemFactory();
		cols[Columns.ID] = new Gtk.ColumnViewColumn("Id", f0);
		cv.append_column(cols[Columns.ID]);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label=new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text(sh.id.to_string());
				sh.notify["id"].connect((s,p) => {
						label.set_text(((SafeHome)s).id.to_string());
					});
			});

        var f1 = new Gtk.SignalListItemFactory();
		cols[Columns.STATUS] = new Gtk.ColumnViewColumn("Enable", f1);
		cv.append_column(cols[Columns.STATUS]);
		f1.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var cbtn=new Gtk.CheckButton();
				list_item.set_child(cbtn);
			});
		f1.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var cbtn = list_item.get_child() as Gtk.CheckButton;
				sh.bind_property("status", cbtn, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
			});

        var f2 = new Gtk.SignalListItemFactory();
		cols[Columns.LAT] = new Gtk.ColumnViewColumn("Latitude", f2);
		cv.append_column(cols[Columns.LAT]);
		f2.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(cbtn);
			});
		f2.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				sh.notify["lat"].connect((s,p) => {
						label.set_text(PosFormat.lat(((SafeHome)s).lat, Mwp.conf.dms));
					});
			});
        var f3 = new Gtk.SignalListItemFactory();
		cols[Columns.LON] = new Gtk.ColumnViewColumn("Longitude", f3);
		cv.append_column(cols[Columns.LAT]);
		f2.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(cbtn);
			});
		f2.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				sh.notify["lat"].connect((s,p) => {
						label.set_text(PosFormat.lat(((SafeHome)s).lat, Mwp.conf.dms));
					});
			});

	}

	public void remove_homes() {
		display_homes(false);
	}

	private void hide_action() {
		_available = false;
		shmarkers.set_interactive(false);
		var state = switcher.get_active();
		if(!state)
			display_homes(false);
		hide();
	}

	public void online_change(uint32 v) {
		var sens = (v >= 0x020700/*Mwp.FCVERS.hasSAFEAPI*/); //.FIXME
		aq_fcs.set_enabled(sens);
		aq_fcl.set_enabled(sens);
	}

	public SafeHome get_home(uint8 idx) {
		return homes[idx];
	}

	private void mclear_item() {
		Gtk.TreeIter iter;
		int i = 0;
        for(bool next = sh_liststore.get_iter_first(out iter); next;
			next = sh_liststore.iter_next(ref iter)) {
            GLib.Value cell;
            sh_liststore.get_value (iter, Column.ID, out cell);
			if(SHPop.idx == -1 || (int)cell == i) {
				clear_item(i, iter);
			}
			i++;
		}
	}

	private void mclear_allitems() {
		SHPop.idx = -1;
		mclear_item();
	}

	private void mcentre_on() {
		Gtk.TreeIter iter;
        for(bool next = sh_liststore.get_iter_first(out iter); next;
			next = sh_liststore.iter_next(ref iter)) {
            GLib.Value cell;
            sh_liststore.get_value (iter, Column.ID, out cell);
			if((int)cell == SHPop.idx) {
				double lat,lon;
				sh_liststore.get (iter, Column.LAT, out lat);
				sh_liststore.get (iter, Column.LON, out lon);
				if(lat != 0 && lon != 0) {
					Gis.map.center_on(lat, lon);
				}
				break;
			}
		}
	}

	private void mtoggle_item() {
		Gtk.TreeIter iter;
		homes[SHPop.idx].enabled = ! homes[SHPop.idx].enabled;
        for(bool next = sh_liststore.get_iter_first(out iter); next;
			next = sh_liststore.iter_next(ref iter)) {
            GLib.Value cell;
            sh_liststore.get_value (iter, Column.ID, out cell);
			if((int)cell == SHPop.idx) {
				sh_liststore.set (iter, Column.STATUS, homes[SHPop.idx].enabled);
				shmarkers.set_safe_colour(SHPop.idx, homes[SHPop.idx].enabled);
				break;
			}
		}
	}


	/**
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
		sh_liststore.set (iter, Column.ID, idx);
		sh_liststore.set (iter, Column.STATUS, false);
		sh_liststore.set (iter, Column.LAT, 0.0);
		sh_liststore.set (iter, Column.LON, 0.0);
		sh_liststore.set (iter, Column.APPALT, 0.0);
		sh_liststore.set (iter, Column.LANDALT, 0.0);
		sh_liststore.set (iter, Column.DIRN1, 0);
		sh_liststore.set (iter, Column.EX1, false);
		sh_liststore.set (iter, Column.DIRN2, 0);
		sh_liststore.set (iter, Column.EX2, false);
		sh_liststore.set (iter, Column.AREF, aref_name(false));
		sh_liststore.set (iter, Column.DREF, dref_name(false));
		shmarkers.hide_safe_home(idx);
	}

	public void drag_action(int idx, double la, double lo) {
		homes[idx].lat = la;
		homes[idx].lon = lo;
		FWPlot.update_laylines(idx, shmarkers.get_marker(idx), homes[idx].enabled);
		shmarkers.update_distance(idx, homes[idx]);
		Gtk.TreeIter iter;
		if(sh_liststore.iter_nth_child (out iter, null, idx)) {
			sh_liststore.set (iter, Column.LAT, homes[idx].lat, Column.LON, homes[idx].lon);
		}
	}

	public void set_distance(uint16 d) {
		shmarkers.set_distance(d);
	}

	/*
	public bool pop_menu() {
		//		if(pop_idx != -1) {
		/*
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
		*/

    private void set_default_loc(int idx) {
		MapUtils.get_centre_location(out homes[idx].lat, out homes[idx].lon);
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
					if (Cli.get_set_val(s, out val)) {
						FWPlot.nav_fw_land_approach_length = val/100;
					}
				} else if (s.contains("nav_fw_loiter_radius")) {
					if (Cli.get_set_val(s, out val)) {
						FWPlot.nav_fw_loiter_radius = val/100;
					}
				}
			}
        }
		for(var j = 0; j < SAFEHOMES.maxhomes; j++) {
			refresh_home(j, hs[j], true);
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
    private void run_chooser(Gtk.FileChooserAction action) {
		IChooser.Filter []ifm = {
			{"Text files", {"txt"}},
		};

		var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
		fc.title = "Safehome File";
		fc.modal = true;
		if (action == Gtk.FileChooserAction.OPEN) { //FIXME enum
			fc.open.begin (Mwp.window, null, (o,r) => {
					try {
						string s;
						var file = fc.open.end(r);
						var fn = file.get_path ();
						load_homes(fn, switcher.active);
					} catch (Error e) {
						MWPLog.message("Failed to open safehome file: %s\n", e.message);
					}
				});
		} else {
			fc.save.begin (Mwp.window, null, (o,r) => {
					try {
						string s;
						var fh = fc.save.end(r);
						filename = fh.get_path ();
                        save_file();
					} catch (Error e) {
						MWPLog.message("Failed to save safehome file: %s\n", e.message);
					}
				});
		}
    }

    public void display() {
        if(!_available) {
			_available = true;
            present ();
            shmarkers.set_interactive(true);
			var state = switcher.get_active();
			if(!state)
				display_homes(true);
		}
    }
}
