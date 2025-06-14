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

namespace NewPos {
	internal string pname;
	public double lat;
	double lon;
	int zoom;
	bool ok;

	[GtkTemplate (ui = "/org/stronnag/mwp/newpos.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		private unowned Gtk.Entry golat;
		[GtkChild]
		private unowned Gtk.Entry golon;
		[GtkChild]
		private unowned Gtk.Entry gozoom;
		[GtkChild]
		private unowned Gtk.Entry goname;
		[GtkChild]
		private unowned Gtk.Button goapp;
		[GtkChild]
		private unowned Gtk.Button gocan;

		public Window(Places.PosItem pi) {
			transient_for = Mwp.window;
			goname.text = pi.name;
			golat.text = PosFormat.lat(pi.lat, Mwp.conf.dms);
			golon.text = PosFormat.lon(pi.lon, Mwp.conf.dms);
			gozoom.text = pi.zoom.to_string();
			ok = false;
			goapp.clicked.connect(() => {
					pname = strdup(goname.text);
					lat = InputParser.get_latitude(golat.text);
					lon = InputParser.get_longitude(golon.text);
					zoom = int.parse(gozoom.text);
					ok = true;
					close();
				});

			gocan.clicked.connect(() => {
					ok = false;
					close();
				});
		}
	}
}

namespace Places {
    public class PosItem  : Object {
        public string name {get; construct set;}
        public double lat {get; construct set;}
        public double lon {get; construct set;}
        public int zoom {get; construct set;}
    }

    private PosItem[]pls;
    private const string DELIMS="\t|;:";
    private  string? cfile = null;

    public   PosItem[] points() {
        return pls;
    }

    private  void parse_delim(string fn) {
        var comma = false;
        var file = File.new_for_path(fn);
        try {
            var dis = new DataInputStream(file.read());
            string line;
            while ((line = dis.read_line (null)) != null) {
                if(line.strip().length > 0 &&
                   !line.has_prefix("#") &&
                   !line.has_prefix(";")) {
                    var parts = line.split_set(DELIMS);
                    if(parts.length <  3) {
                        parts = line.split(",");
                        comma = true;
                    }

                    if(parts.length > 2) {
                        var p = new PosItem();
                        p.lat = DStr.strtod(parts[1],null);
                        p.lon = DStr.strtod(parts[2],null);
                        p.name = parts[0];
                        if(parts.length > 3)
                            p.zoom = int.parse(parts[3]);
                        else
                            p.zoom = -1;
                        pls += p;
                    }
                }
            }
        } catch (Error e) {
            error ("%s", e.message);
        }

		if(pls.length > 0 && comma)
            save_file();
    }

    public  PosItem[] get_places() {
        string? fn;
        pls = {};
        fn = find_conf_file("places");
		if(fn != null) {
            parse_delim(fn);
            cfile = fn;
        }
        return pls;
    }

    private  string? find_conf_file(string fn) {
        var uc =  Environment.get_user_config_dir();
        var cfile = GLib.Path.build_filename(uc,"mwp",fn);
        var n = Posix.access(cfile, Posix.R_OK);
        if (n == 0)
            return cfile;
        else
            return null;
    }

    public  void save_file() {
        var uc =  Environment.get_user_config_dir();
        var cfile = GLib.Path.build_filename(uc,"mwp","places");
        var fp = FileStream.open (cfile, "w");
        if (fp != null) {
            fp.write("# name\tlat\tlon\tzoom\n".data);
            foreach(var p in pls) {
                var s = "%s\t%f\t%f\t%d\n".printf(p.name, p.lat, p.lon, p.zoom);
                fp.write(s.data);
            }
        }
    }

    public  void replace (PosItem[] ps) {
        pls = ps;
        save_file();
    }
}

class PlaceEdit : Adw.Window {
	GLib.ListStore lstore;
    Gtk.SingleSelection ssel;
    Gtk.Button[] buttons;
	Gtk.PopoverMenu pop;
	Gtk.ColumnView cv;
	int poprow = 0;

    public signal void places_changed();

    enum Buttons {
        ADD,
        OK
    }

	private void setup_cv() {
		cv = new Gtk.ColumnView(null);
		lstore = new GLib.ListStore(typeof(Places.PosItem));
		var sm = new Gtk.SortListModel(lstore, cv.sorter);
		ssel = new Gtk.SingleSelection(sm);
		cv.set_model(ssel);
		cv.show_column_separators = true;
		cv.show_row_separators = true;
		var f0 = new Gtk.SignalListItemFactory();
		var c0 = new Gtk.ColumnViewColumn("Name", f0);
		cv.append_column(c0);
		c0.expand = true;
		f0.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var label=new Gtk.Label("");
				list_item.set_child(label);
			});
		f0.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				Places.PosItem pi = list_item.get_item() as Places.PosItem;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text(pi.name.to_string());
				pi.bind_property("name", label, "label", BindingFlags.SYNC_CREATE);
			});

		var txtsorter = new Gtk.CustomSorter((a,b) => {
				return strcmp(((Places.PosItem)a).name,((Places.PosItem)b).name);
			});
		c0.set_sorter(txtsorter);

		var f1 = new Gtk.SignalListItemFactory();
		var c1 = new Gtk.ColumnViewColumn("Latitude", f1);
		cv.append_column(c1);
		f1.setup.connect((f,o) => {
          Gtk.ListItem list_item = (Gtk.ListItem)o;
          var label=new Gtk.Label("");
          list_item.set_child(label);
        });
		f1.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				Places.PosItem pi = list_item.get_item() as Places.PosItem;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text(PosFormat.lat(pi.lat, Mwp.conf.dms));
				pi.notify["lat"].connect((s,p) => {
						label.set_text(PosFormat.lat(((Places.PosItem)s).lat, Mwp.conf.dms));
					});
			});

		var f2 = new Gtk.SignalListItemFactory();
		var c2 = new Gtk.ColumnViewColumn("Longitude", f2);
		cv.append_column(c2);
		f2.setup.connect((f,o) => {
          Gtk.ListItem list_item = (Gtk.ListItem)o;
          var label=new Gtk.Label("");
          list_item.set_child(label);
        });
		f2.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				Places.PosItem pi = list_item.get_item() as Places.PosItem;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text(PosFormat.lon(pi.lon, Mwp.conf.dms));
				pi.notify["lon"].connect((s,p) => {
						label.set_text(PosFormat.lon(((Places.PosItem)s).lon, Mwp.conf.dms));
					});
			});

		var f3 = new Gtk.SignalListItemFactory();
		var c3 = new Gtk.ColumnViewColumn("Zoom", f3);
		cv.append_column(c3);
		f3.setup.connect((f,o) => {
          Gtk.ListItem list_item = (Gtk.ListItem)o;
          var label=new Gtk.Label("");
          list_item.set_child(label);
        });
		f3.bind.connect((f,o) => {
				Gtk.ListItem list_item =  (Gtk.ListItem)o;
				Places.PosItem pi = list_item.get_item() as Places.PosItem;
				var label = list_item.get_child() as Gtk.Label;
				label.set_text(pi.zoom.to_string());
				pi.notify["zoom"].connect((s,p) => {
						label.set_text(((Places.PosItem)s).zoom.to_string());
					});
			});
		// -----------  Line edit -----------
		var fx = new Gtk.SignalListItemFactory();
		var cx = new Gtk.ColumnViewColumn("", fx);
		cv.append_column(cx);
		fx.setup.connect((f,o) => {
				Gtk.ListItem list_item = (Gtk.ListItem)o;
				var btn = new Gtk.Button.from_icon_name("document-edit-symbolic");
				btn.sensitive = true;
				list_item.set_child(btn);
				btn.clicked.connect(() => {
						var idx = list_item.position;
						var  pi = lstore.get_item(idx) as Places.PosItem;
						if (pi != null) {
							edit_position(pi, false);
						}
					});
			});
	}

	public PlaceEdit () {
        var scrolled = new Gtk.ScrolledWindow ();
        title = "Edit Stored Places";
        Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);

		var tbox = new Adw.ToolbarView();
		var headerBar = new Adw.HeaderBar();
		tbox.add_top_bar(headerBar);

		setup_cv();
        cv.vexpand = true;
        cv.hexpand = true;
        scrolled.set_child(cv);
		scrolled.propagate_natural_height = true;
		scrolled.propagate_natural_width = true;
        buttons = {
            new Gtk.Button.from_icon_name ("list-add-symbolic"),
            new Gtk.Button.with_label ("OK"),
        };
        Gtk.Box bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        foreach (unowned Gtk.Button button in buttons) {
			button.halign = Gtk.Align.END;
            bbox.append (button);
        }
		buttons[0].tooltip_text = "Add new place";

		bbox.halign = Gtk.Align.END;
		bbox.hexpand = true;
		build_mm();
		var gestc = new Gtk.GestureClick();
		((Gtk.Widget)cv).add_controller(gestc);
		gestc.set_button(3);
		gestc.released.connect((n,x,y) => {
				handle_mb3(cv, x, y);
				/*
				poprow = Utils.get_row_at(cv, y);
				Gdk.Rectangle rect = { (int)x, (int)y, 1, 1};
				pop.has_arrow = false;
				pop.set_pointing_to(rect);
				pop.popup();
				*/
            });


		var gestl = new Gtk.GestureLongPress();
		gestl.touch_only = true;
		((Gtk.Widget)cv).add_controller(gestl);
		gestl.pressed.connect((x,y) => {
				handle_mb3(cv, x, y);
			});

		box.append(scrolled);
		tbox.set_content (box);
		bbox.add_css_class("toolbar");
		tbox.add_bottom_bar(bbox);
		set_content(tbox);

		set_transient_for(Mwp.window);
        close_request.connect (() => {
                visible=false;
                return true;
            });

        buttons[Buttons.ADD].clicked.connect (() => {
				double clat,clon;
				MapUtils.get_centre_location(out clat, out clon);
				var pi = new Places.PosItem();
				pi.name = "New Item";
				pi.lat = clat;
				pi.lon = clon;
				pi.zoom = (int)Gis.map.viewport.get_zoom_level();
				edit_position(pi, true);
			});

        buttons[Buttons.OK].clicked.connect (() => {
                Places.PosItem[]ps={};
				for(var j = 0; j < lstore.get_n_items(); j++) {
					var pi = lstore.get_item(j) as Places.PosItem;
					var name = pi.name.strip();
					if (name != "") {
						ps += pi;
					}
				}
                Places.replace(ps);
                places_changed();
				visible=false;
            });
    }

	private void handle_mb3(Gtk.Widget cv, double x, double y) {
		poprow = Utils.get_row_at(cv, y);
		Gdk.Rectangle rect = { (int)x, (int)y, 1, 1};
		pop.has_arrow = false;
		pop.set_pointing_to(rect);
		pop.popup();
	}

	private void edit_position(Places.PosItem pi, bool insert) {
		var w = new NewPos.Window(pi);
		w.close_request.connect (() => {
				if(NewPos.ok) {
					bool sortme = (pi.name != NewPos.pname);
					pi.name = NewPos.pname;
					pi.lat = NewPos.lat;
					pi.lon = NewPos.lon;
					pi.zoom = NewPos.zoom;
					if(insert) {
						lstore.insert_sorted(pi, (a,b) => {
								return strcmp(((Places.PosItem)a).name, ((Places.PosItem)b).name);
							});
					} else {
						if(sortme) {
							lstore.sort((a,b) => {
									return strcmp(((Places.PosItem)a).name, ((Places.PosItem)b).name);
								});
						}
					}
				}
				return false;
			});
		w.present();
	}

	private void build_mm() {
		var xml = """
			<?xml version="1.0" encoding="UTF-8"?>
			<interface>
			<menu id="app-menu">
			<section>
			<item>
			<attribute name="label">Zoom to location</attribute>
			<attribute name="action">view.zoom</attribute>
			</item>
			<item>
			<attribute name="label">Set location from current view</attribute>
			<attribute name="action">view.setloc</attribute>
			</item>
			<item>
			<attribute name="label">Delete location</attribute>
			<attribute name="action">view.delloc</attribute>
			</item>
			</section>
			</menu>
			</interface>
			""";

		var dg = new GLib.SimpleActionGroup();
		var sbuilder = new Gtk.Builder.from_string(xml, -1);
        var menu = sbuilder.get_object("app-menu") as GLib.MenuModel;
		pop = new Gtk.PopoverMenu.from_model(menu);
		var aq = new GLib.SimpleAction("zoom",null);
		aq.activate.connect(() => {
				if(poprow != -1) {
					var pi = lstore.get_item((uint)poprow) as Places.PosItem;
					if (pi.zoom > 0) {
						Mwp.set_zoom_sanely(pi.zoom);
					}
					MapUtils.centre_on(pi.lat, pi.lon);
					Mwp.set_pos_label(Mwp.clat, Mwp.clon);
				}
            });
		dg.add_action(aq);

		aq = new GLib.SimpleAction("setloc",null);
		aq.activate.connect(() => {
				if(poprow != -1) {
					double clat, clon;
					MapUtils.get_centre_location(out clat, out clon);
					var pi = lstore.get_item((uint)poprow) as Places.PosItem;
					pi.lat = clat;
					pi.lon = clon;
					pi.zoom = (int)Gis.map.viewport.get_zoom_level();
				}
			});
		dg.add_action(aq);

		aq = new GLib.SimpleAction("delloc",null);
		aq.activate.connect(() => {
				lstore.remove(poprow);
			});
		dg.add_action(aq);

		this.insert_action_group("view", dg);
		pop.set_parent(this);
    }

	public new void show() {
		load_places();
        base.present();
    }

	public void load_places() {
		lstore.remove_all();
		for(var j = 0; j < Places.pls.length; j++) {
			lstore.insert_sorted(Places.pls[j], (a,b) => {
					return strcmp(((Places.PosItem)a).name, ((Places.PosItem)b).name);
				});
		}
	}
}
