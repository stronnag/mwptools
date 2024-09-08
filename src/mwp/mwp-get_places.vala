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
    public struct PosItem {
        string name;
        double lat;
        double lon;
        int zoom;
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
                        var p = PosItem();
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
    Gtk.TreeView view;
    Gtk.ListStore listmodel;
    Gtk.Button[] buttons;
    Gtk.TreeIter miter;
	Gtk.PopoverMenu pop;

    public signal void places_changed();

    enum Column {
        NAME,
        LAT,
        LON,
        ZOOM,
        NO_COLS
    }

    enum Buttons {
        ADD,
        OK
    }

    public PlaceEdit () {
        var scrolled = new Gtk.ScrolledWindow ();
        set_default_size (360, 360);
        title = "Edit Stored Places";
        Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
		var headerBar = new Adw.HeaderBar();
		box.append(headerBar);
        view = new Gtk.TreeView ();
        setup_treeview ();
        view.vexpand = true;
        view.hexpand = true;
        scrolled.set_child(view);
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
		box.add_controller(gestc);
		gestc.set_button(3);
		gestc.released.connect((n,x,y) => {
				if (get_selected_iter(out miter)) {
					GLib.Value _cell;
					listmodel.get_value (miter, Column.NAME, out _cell);
					Gdk.Rectangle rect = { (int)x, (int)y, 1, 1};
					pop.set_pointing_to(rect);
					pop.popup();
				}
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
                Gtk.TreeIter iter;
                listmodel.append (out iter);
				double clat,clon;
				MapUtils.get_centre_location(out clat, out clon);
                listmodel.set (iter,
                               Column.NAME, "",
                               Column.LAT, clat,
                               Column.LON, clon,
                               Column.ZOOM, Gis.map.viewport.get_zoom_level());
            });

        buttons[Buttons.OK].clicked.connect (() => {
                Gtk.TreeIter iter;
                Places.PosItem[]ps={};

                for(bool next=listmodel.get_iter_first(out iter); next;
                    next=listmodel.iter_next(ref iter)) {
                    string s;
                    double la,lo;
                    int zoom;
                    GLib.Value cell;
                    listmodel.get_value (iter, Column.NAME, out cell);
                    s = (string)cell;
                    s = s.strip();
                    if (s.length > 0) {
                        listmodel.get_value (iter, Column.LAT, out cell);
                        la = (double)cell;
                        listmodel.get_value (iter, Column.LON, out cell);
                        lo = (double)cell;
                        listmodel.get_value (iter, Column.ZOOM, out cell);
                        zoom = (int)cell;
                        var p = Places.PosItem(){name = s,lat = la, lon = lo, zoom = zoom};
                        ps += p;
                    }
                }
                Places.replace(ps);
                places_changed();
                hide();
            });
    }

    private void setup_treeview () {
        listmodel = new Gtk.ListStore (Column.NO_COLS,
                                       typeof (string),
                                       typeof (double),
                                       typeof (double),
                                       typeof (int));

        view.set_model (listmodel);
        var cell = new Gtk.CellRendererText ();
        cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "Name",
                                            cell, "text",
                                            Column.NAME);

        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                Gtk.TreeIter iter_val;
                listmodel.get_iter (out iter_val, new Gtk.TreePath.from_string (path));
                listmodel.set_value (iter_val, Column.NAME, new_text);
            });


        var col = view.get_column(Column.NAME);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, Column.NAME, out v);
                _cell.set_property("text",(string)v);
            });

        col.set_sort_column_id(Column.NAME);

        cell = new Gtk.CellRendererText ();
		cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "Latitude",
                                            cell, "text", Column.LAT);
        col = view.get_column(Column.LAT);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, Column.LAT, out v);
                double val = (double)v;
                string s = PosFormat.lat(val,Mwp.conf.dms);
                _cell.set_property("text",s);
            });


        cell = new Gtk.CellRendererText ();
		cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "Longitude",
                                            cell, "text", Column.LON);
        col = view.get_column(Column.LON);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, Column.LON, out v);
                double val = (double)v;
                string s = PosFormat.lon(val,Mwp.conf.dms);
                _cell.set_property("text",s);
            });


        var zcell = new Gtk.CellRendererText ();
		zcell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "Zoom", zcell, "text", Column.ZOOM);
        ((Gtk.CellRendererText)zcell).edited.connect((path,new_text) => {
                Gtk.TreeIter iter;
                listmodel.get_iter (out iter, new Gtk.TreePath.from_string (path));
                listmodel.set_value (iter, Column.ZOOM, int.parse(new_text));
            });

        view.unselect_all();
        view.hover_selection = true;
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
                Value v;
                listmodel.get_value(miter, Column.LAT, out v);
                double la = (double)v;
                listmodel.get_value(miter, Column.LON, out v);
                double lo = (double)v;
                listmodel.get_value(miter, Column.ZOOM, out v);
                int zoom = (int)v;
                Gis.map.center_on(la,lo);
                if (zoom > 0) {
					Mwp.set_zoom_sanely(zoom);
				}
				Mwp.set_pos_label(Mwp.clat, Mwp.clon);

            });
		dg.add_action(aq);

		aq = new GLib.SimpleAction("setloc",null);
		aq.activate.connect(() => {
				double clat,clon;
				MapUtils.get_centre_location(out clat, out clon);
				listmodel.set (miter,
                               Column.LAT, clat,
                               Column.LON, clon,
                               Column.ZOOM, Gis.map.viewport.get_zoom_level());
			});
		dg.add_action(aq);

		aq = new GLib.SimpleAction("delloc",null);
		aq.activate.connect(() => {
                listmodel.remove(ref miter);
			});
		dg.add_action(aq);
		this.insert_action_group("view", dg);
		pop.set_parent(this);
    }

    private bool  get_selected_iter(out Gtk.TreeIter iter) {
        iter={};
        var sel = view.get_selection ();
        if(sel.count_selected_rows () == 1) {
            var rows = sel.get_selected_rows(null);
            listmodel.get_iter (out iter, rows.nth_data(0));
            return true;
        }
        return false;
    }

    public void insert(Places.PosItem r)  {
        Gtk.TreeIter iter;
        listmodel.append (out iter);
        listmodel.set (iter,
                       Column.NAME,r.name,
                       Column.LAT, r.lat,
                       Column.LON, r.lon,
                       Column.ZOOM, r.zoom);
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
        listmodel.clear();
        foreach(var pl in Places.points()) {
            insert(pl);
        }
    }
}
