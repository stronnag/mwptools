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
    Gtk.SingleSelection lmodel;
    Gtk.ColumnViewColumn c0;
    Gtk.ColumnViewColumn c1;
    Gtk.ColumnViewColumn c2;
    Gtk.ColumnViewColumn c3;
    Gtk.Button[] buttons;
	Gtk.PopoverMenu pop;
	Gtk.ColumnView lv;
	int poprow = 0;

    public signal void places_changed();

    enum Buttons {
        ADD,
        OK
    }

	private void setup_cv() {
		lv = new Gtk.ColumnView(null);
		lstore = new GLib.ListStore(typeof(Places.PosItem));
		lmodel = new Gtk.SingleSelection(lstore);
		lv.set_model(lmodel);
		lv.show_column_separators = true;
		lv.show_row_separators = true;
		var f0 = new Gtk.SignalListItemFactory();
		c0 = new Gtk.ColumnViewColumn("Name", f0);
		lv.append_column(c0);
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


		var f1 = new Gtk.SignalListItemFactory();
		c1 = new Gtk.ColumnViewColumn("Latitude", f1);
		lv.append_column(c1);
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
		c2 = new Gtk.ColumnViewColumn("Longitude", f2);
		lv.append_column(c2);
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
		c3 = new Gtk.ColumnViewColumn("Zoom", f3);
		lv.append_column(c3);
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
	}

    public PlaceEdit () {
        var scrolled = new Gtk.ScrolledWindow ();
        set_default_size (360, 360);
        title = "Edit Stored Places";
        Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
		var headerBar = new Adw.HeaderBar();
		box.append(headerBar);
		setup_cv();
        lv.vexpand = true;
        lv.hexpand = true;
        scrolled.set_child(lv);
        buttons = {
            new Gtk.Button.from_icon_name ("gtk-add"),
            new Gtk.Button.with_label ("OK"),
        };
        Gtk.Box bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        foreach (unowned Gtk.Button button in buttons) {
			button.halign = Gtk.Align.END;
            bbox.append (button);
        }
		bbox.halign = Gtk.Align.END;
		bbox.hexpand = true;
		build_mm();
		var gestc = new Gtk.GestureClick();
		((Gtk.Widget)lv).add_controller(gestc);
		gestc.set_button(3);
		gestc.released.connect((n,x,y) => {
				poprow = Utils.get_row_at(lv, x, y);
				Gdk.Rectangle rect = { (int)x, (int)y, 1, 1};
				pop.has_arrow = false;
				pop.set_pointing_to(rect);
				pop.popup();
            });


		box.append(scrolled);
        box.append (bbox);
		set_content (box);

		set_transient_for(Mwp.window);
        close_request.connect (() => {
                this.hide();
                return true;
            });

        buttons[Buttons.ADD].clicked.connect (() => {
				double clat,clon;
				MapUtils.get_centre_location(out clat, out clon);
				var pi = new Places.PosItem();
				pi.name = "";
				pi.lat = clat;
				pi.lon = clon;
				pi.zoom = (int)Gis.map.viewport.get_zoom_level();
				Places.pls += pi;
				insert(pi);
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
				hide();
            });
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
					Gis.map.center_on(pi.lat, pi.lon);
					if (pi.zoom > 0) {
						Mwp.set_zoom_sanely(pi.zoom);
					}
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

    public void insert(Places.PosItem r)  {
		lstore.append(r);
    }

	public new void show() {
		load_places();
        base.present();
    }
	/*
		  public new void hide() {
		  base.hide();
		  }
	*/
    public void load_places() {
		lstore.remove_all();
		//lstore.splice(0, lstore.n_items, Places.pls);
		for(var j = 0; j < Places.pls.length; j++) {
			insert(Places.pls[j]);
		}
    }
}
