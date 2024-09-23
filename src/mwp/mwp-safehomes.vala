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

namespace Safehome {
	const int MAXHOMES=8;
	public SafeHomeDialog manager;
	//	GLib.ListStore lstore;
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

	public SafeHomeMarkers() {
		scolour.parse("rgba(0xfb, 0xea, 0x04, 0.4)");
		white.parse("white");
		onscreen = new bool[Safehome.MAXHOMES];
		safept = new  MWPLabel[Safehome.MAXHOMES];
		safed = {};
		safel = {};
		safelayer = new Shumate.MarkerLayer(Gis.map.viewport);
		Gis.map.insert_layer_behind (safelayer, Gis.mm_layer); // below mission path
		var llist = new List<uint>();
		llist.append(5);
		llist.append(5);
		llist.append(5);
		llist.append(5);

		for(var idx = 0; idx < Safehome.MAXHOMES; idx++) {
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
					var pop = new Gtk.PopoverMenu.from_model(SHPop.mmodel);
					var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL,1);
					var plab = new Gtk.Label("# %d".printf(idx));
					plab.hexpand = true;
					box.append(plab);
					if(n == -1) {
						pop.set_autohide(false);
						var button = new Gtk.Button.from_icon_name("window-close");
						button.halign = Gtk.Align.END;
						box.append(button);
						button.clicked.connect(() => {
								pop.popdown();
							});
					} else {
						pop.set_autohide(true);
					}
					pop.add_child(box, "label");
					pop.set_has_arrow(true);
					pop.set_parent(safept[idx]);
					pop.popup();
				});
			onscreen[idx] = true;
		}
		set_safe_colour(idx, h.enabled);
		safept[idx].latitude = h.lat;
		safept[idx].longitude = h.lon;
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
		for(var i = 0; i < Safehome.MAXHOMES; i++) {
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

public class  SafeHomeDialog : Adw.Window {
	private bool _available = false;
	private string filename;
	private GLib.ListStore lstore;
	private Gtk.ColumnView cv;
	Gtk.SingleSelection lsel;

	private Gtk.Switch switcher;
	private GLib.SimpleAction aq_fcl;
	private GLib.SimpleAction aq_fcs;

	public signal void request_safehomes(uint8 first, uint8 last);
	public signal void notify_publish_request();

	private SafeHomeMarkers shmarkers;

	private void upsert(uint idx, SafeHome _sh) {
		var sh = lstore.get_item(idx) as SafeHome;
		if (sh == null) {
			lstore.insert(idx, _sh);
		} else {
			sh.enabled = _sh.enabled;
			sh.lat = _sh.lat;
			sh.lon = _sh.lon;
			sh.appalt = _sh.appalt;
			sh.landalt =  _sh.landalt;
			sh.dref = _sh.dref;
			sh.aref = _sh.aref;
			sh.dirn1 = _sh.dirn1;
			sh.ex1 = _sh.ex1;
			sh.dirn2 = _sh.dirn2;
			sh.ex2 = _sh.ex2;
		}
	}

	public void relocate_safehomes() {
		for(var j = 0; j < Safehome.MAXHOMES; j++) {
			var sh = lstore.get_item(j) as SafeHome;
			if (sh.enabled) {
				var lat = sh.lat;
				var lon = sh.lon;
				Rebase.relocate(ref lat, ref lon);
				sh.lat = lat;
				sh.lon = lon;
			}
		}
	}

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
				request_safehomes(0, (uint8)Safehome.MAXHOMES);
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
        for(var i = 0; i < Safehome.MAXHOMES; i++) {
            var sh = new SafeHome();
            lstore.insert(i, sh);
			var idx = i;
			sh.notify["enabled"].connect((s,p) => {
					if (((SafeHome)s).enabled) {
						if (((SafeHome)s).lat == 0 && ((SafeHome)s).lon == 0) {
							set_default_loc(idx);
						}
						shmarkers.show_safe_home(idx, ((SafeHome)s));
					} else {
						shmarkers.set_safe_colour(idx, false);
					}
				});
        }
		sbox.margin_start = 8;
		sbox.margin_end = 8;

		sbox.append (cv);

		shmarkers = new SafeHomeMarkers();
		shmarkers.safept_move.connect((idx,la,lo) => {
				drag_action(idx, la, lo);
			});
		set_content(sbox);
	}

	private void create_cv() {
		cv = new Gtk.ColumnView(null);
		lstore = new GLib.ListStore(typeof(SafeHome));
		var sm = new Gtk.SortListModel(lstore, cv.sorter);
		lsel = new Gtk.SingleSelection(sm);
		cv.set_model(lsel);
		cv.show_column_separators = true;
		cv.show_row_separators = true;

        var f0 = new Gtk.SignalListItemFactory();
		var c0  = new Gtk.ColumnViewColumn("Id", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label=new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var label = list_item.get_child() as Gtk.Label;
                label.set_text(list_item.position.to_string());
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Enable", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var cbtn=new Gtk.CheckButton();
				list_item.set_child(cbtn);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var cbtn = list_item.get_child() as Gtk.CheckButton;
				sh.bind_property("enabled", cbtn, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
			});

        f0 = new Gtk.SignalListItemFactory();
        c0 = new Gtk.ColumnViewColumn("Latitude", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text(PosFormat.lat(sh.lat, Mwp.conf.dms));
				sh.notify["lat"].connect((s,p) => {
						label.set_text(PosFormat.lat(((SafeHome)s).lat, Mwp.conf.dms));
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Longitude", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text(PosFormat.lon(sh.lon, Mwp.conf.dms));
				sh.notify["lon"].connect((s,p) => {
						label.set_text(PosFormat.lon(((SafeHome)s).lon, Mwp.conf.dms));
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Land Alt.", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text("%.2f".printf(sh.landalt));
				sh.notify["landalt"].connect((s,p) => {
						label.set_text("%.2f".printf(((SafeHome)s).landalt));
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Approach Alt.", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text("%.2f".printf(sh.appalt));
				sh.notify["appalt"].connect((s,p) => {
						label.set_text("%.2f".printf(((SafeHome)s).appalt));
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Direction1", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text("%4d".printf(sh.dirn1));
				sh.notify["dirn1"].connect((s,p) => {
						label.set_text("%4d".printf(((SafeHome)s).dirn1));
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Exc-1", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text((sh.ex1) ? "✔" : "");
				sh.notify["ex1"].connect((s,p) => {
						label.set_text((((SafeHome)s).ex1) ? "✔" : "");
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Direction2", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text("%4d".printf(sh.dirn2));
				sh.notify["dirn2"].connect((s,p) => {
						label.set_text("%4d".printf(((SafeHome)s).dirn2));
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Exc-2", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text((sh.ex2) ? "✔" : "");
				sh.notify["ex21"].connect((s,p) => {
						label.set_text((((SafeHome)s).ex2) ? "✔" : "");
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Alt.Mode", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				var txt = aref_name(sh.aref);
				label.set_text(txt);
				sh.notify["aref"].connect((s,p) => {
						var atxt = aref_name(((SafeHome)s).aref);
						label.set_text(atxt);
					});
			});

        f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("From", f0);
		cv.append_column(c0);
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label = new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				var sh = list_item.get_item() as SafeHome;
				var label = list_item.get_child() as Gtk.Label;
				var txt = dref_name(sh.dref);
				label.set_text(txt);
				sh.notify["dref"].connect((s,p) => {
						var atxt = dref_name(((SafeHome)s).dref);
						label.set_text(atxt);
					});
			});

		// -----------  Line edit -----------
		var fx = new Gtk.SignalListItemFactory();
		var cx = new Gtk.ColumnViewColumn("", fx);
		cv.append_column(cx);
		fx.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var btn = new Gtk.Button.from_icon_name("document-edit");
				btn.sensitive = true;
				list_item.set_child(btn);
				btn.clicked.connect(() => {
						var idx = list_item.position;
						var  sh = lstore.get_item(idx) as SafeHome;
						if (sh != null) {
							var w = new  Safehome.Editor();
							w.setup((int)idx, sh);
							w.ready.connect(() => {
									var relaid = false;
									var sn = w.get_result();
									if (sh.landalt != sn.landalt) {
										sh.landalt = sn.landalt;
										FWApproach.set_landalt((int)idx, sh.landalt);
									}
									if (sh.appalt != sn.appalt) {
										sh.appalt = sn.appalt;
										FWApproach.set_appalt((int)idx, sh.appalt);
									}
									if (sh.dirn1 != sn.dirn1) {
										sh.dirn1 = sn.dirn1;
										FWApproach.set_dirn1((int)idx, sh.dirn1);
										relaid = true;
									}
									if (sh.dirn2 != sn.dirn2) {
										sh.dirn2 = sn.dirn2;
										FWApproach.set_dirn2((int)idx, sh.dirn2);
										relaid = true;
									}
									if (sh.ex1 != sn.ex1) {
										sh.ex1 = sn.ex1;
										FWApproach.set_ex1((int)idx, sh.ex1);
										relaid = true;
									}
									if (sh.ex2 != sn.ex2) {
										sh.ex2 = sn.ex2;
										FWApproach.set_ex2((int)idx, sh.ex2);
										relaid = true;
									}
									if (sh.aref != sn.aref) {
										sh.aref = sn.aref;
										FWApproach.set_aref((int)idx, sh.aref);
									}
									if (sh.dref != sn.dref) {
										sh.dref = sn.dref;
										FWApproach.set_dref((int)idx, sh.dref);
										relaid = true;
									}
									if(relaid && (sh.lat != 0.0 && sh.lon != 0.0)) {
										shmarkers.refresh_lay((int)idx, sh);
									}
								});
							w.close_request.connect(() => {
									this.visible = true;
									return false;
								});
							this.visible = false;
							w.present();
						}
					});
			});
	}

	private string aref_name(bool a)  {
		return (a) ? "AMSL" : "Relative";
	}

	private string dref_name(bool d)  {
		return (d) ? "Right" : "Left";
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
		visible=false;
	}

	public void online_change(uint32 v) {
		var sens = (v >= 0x020700/*Mwp.FCVERS.hasSAFEAPI*/); //.FIXME
		aq_fcs.set_enabled(sens);
		aq_fcl.set_enabled(sens);
	}

	public SafeHome get_home(uint8 idx) {
		return lstore.get_item(idx) as SafeHome;
	}

	private void mclear_item() {
		clear_item(SHPop.idx);
	}

	private void mclear_allitems() {
		for(var j = 0; j < Safehome.MAXHOMES; j++) {
			clear_item(j);
		}
	}

	private void mcentre_on() {
		var sh = lstore.get_item(SHPop.idx) as SafeHome;
		if(sh.lat != 0 && sh.lon != 0) {
			Gis.map.center_on(sh.lat, sh.lon);
		}
    }

	private void mtoggle_item() {
		var sh = lstore.get_item(SHPop.idx) as SafeHome;
		sh.enabled = ! sh.enabled ;
		shmarkers.set_safe_colour(SHPop.idx, sh.enabled);
	}

	public void receive_safehome(uint8 idx, SafeHome shm) {
		refresh_home(idx,  shm);
	}

	private void clear_item(int idx) {
		FWApproach.approach l = {};
		FWApproach.set(idx,l);
		var sh = new SafeHome();
		upsert(idx, sh);
		shmarkers.hide_safe_home(idx);
    }

	public void drag_action(int idx, double la, double lo) {
		var sh = lstore.get_item(idx) as SafeHome;
		sh.lat = la;
		sh.lon = lo;
		FWPlot.update_laylines(idx, shmarkers.get_marker(idx), sh.enabled);
		shmarkers.update_distance(idx, sh);
	}

	public void set_distance(uint16 d) {
		shmarkers.set_distance(d);
	}

    private void set_default_loc(int idx) {
		double lat;
		double lon;
		MapUtils.get_centre_location(out lat, out lon);
		var sh = lstore.get_item(idx) as SafeHome;
		sh.lat = lat;
		sh.lon = lon;
    }

    private void read_file() {
        FileStream fs = FileStream.open (filename, "r");
        if(fs == null) {
            return;
        }
        string s;
		while((s = fs.read_line()) != null) {
            if(s.has_prefix("safehome ")) {
                var sh = new SafeHome();
                var parts = s.split_set(" ");
				var idx = int.parse(parts[1]);
				if (idx >= 0 && idx < Safehome.MAXHOMES) {
					sh.enabled = (parts[2] == "1") ? true : false;
					sh.lat = double.parse(parts[3]) /10000000.0;
					sh.lon = double.parse(parts[4]) /10000000.0;
                    upsert(idx, sh);
				}
			} else if(s.has_prefix("fwapproach ")) {
				var parts = s.split_set(" ");
				var idx = int.parse(parts[1]);
				if (idx >= 0 && idx < FWApproach.MAXAPPROACH) {
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
						if (idx < Safehome.MAXHOMES) {
							var sh = lstore.get_item(idx) as SafeHome;
							if(sh != null) {
								sh.appalt = l.appalt;
								sh.landalt =  l.landalt;
								sh.dref = l.dref;
								sh.aref = l.aref;
								sh.dirn1 = l.dirn1;
								sh.ex1 = l.ex1;
								sh.dirn2 = l.dirn2;
								sh.ex2 = l.ex2;
							} else {
								MWPLog.message("Failed to find SH for FWA %d\n", idx);
							}
						}
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
		for(var j = 0; j < Safehome.MAXHOMES; j++) {
			var sh = lstore.get_item(j) as SafeHome;
			redraw_home(j, sh);
		}

    }

    private void refresh_home(int idx, SafeHome h, bool forced = false) {
        var sh = lstore.get_item(idx) as SafeHome;
        sh.enabled = h.enabled;
        sh.lat = h.lat;
        sh.lon = h.lon;
		FWApproach.approach lnd = FWApproach.get(idx);

        sh.appalt = lnd.appalt;
        sh.landalt = lnd.landalt;
        sh.dirn1 = lnd.dirn1;
        sh.ex1 = lnd.ex1;
        sh.dirn2 = lnd.dirn2;
        sh.ex2 =  lnd.ex2;
        sh.aref = lnd.aref;
        sh.dref = lnd.dref;
		redraw_home(idx, sh);
    }


	void redraw_home(int idx, SafeHome sh, bool forced = true) {
		if(switcher.active || forced) {
            if(sh.lat != 0 && sh.lon != 0)
                shmarkers.show_safe_home(idx, sh);
            else
                shmarkers.hide_safe_home(idx);
        }
	}

    private void display_homes(bool state) {
        for (var idx = 0; idx < Safehome.MAXHOMES; idx++) {
            if(state) {
                var sh = lstore.get_item(idx) as SafeHome;
                if(sh.lat != 0 && sh.lon != 0) {
                    shmarkers.show_safe_home(idx, sh);
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
        for(var idx = 0; idx < Safehome.MAXHOMES; idx++) {
            var sh = lstore.get_item(idx) as SafeHome;
			var ena = (sh.enabled) ? 1 : 0;
			sb.append_printf("safehome %d %d %d %d\n", idx, ena,
							 (int)(sh.lat*10000000), (int)(sh.lon*10000000));
        }

		UpdateFile.save(filename, "safehome", sb.str);

		sb = new StringBuilder();
		for(var j = 0; j < FWApproach.MAXAPPROACH; j++) {
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
						var fh = fc.save.end(r);
						filename = fh.get_path ();
                        save_file();
					} catch (Error e) {
						MWPLog.message("Failed to save safehome file: %s\n", e.message);
					}
				});
		}
    }

    public void display_ui() {
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
