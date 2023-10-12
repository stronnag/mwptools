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
        if((fn = find_conf_file("places")) != null) {
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

class PlaceEdit : Object {
    Gtk.Window w;
    Gtk.TreeView view;
    Gtk.ListStore listmodel;
    Gtk.Button[] buttons;
    Gtk.Menu menu;
    Gtk.MenuItem mname;
    Gtk.TreeIter miter;

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

    public PlaceEdit (Gtk.Window? _w, Champlain.View cv) {
        w = new Gtk.Window();
        w.set_position(Gtk.WindowPosition.MOUSE);
        var scrolled = new Gtk.ScrolledWindow (null, null);
        w.set_default_size (360, 360);
        w.title = "Edit Stored Places";
        view = new Gtk.TreeView ();
        setup_treeview ();
        view.expand = true;
        var grid = new Gtk.Grid ();
        scrolled.add(view);
        buttons = {
            new Gtk.Button.from_icon_name ("gtk-add"),
            new Gtk.Button.with_label ("OK"),
        };
        Gtk.ButtonBox bbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        bbox.set_layout (Gtk.ButtonBoxStyle.START);
        bbox.set_spacing (5);
        foreach (unowned Gtk.Button button in buttons) {
            bbox.add (button);
        }
        build_mm(cv);

        Gtk.Box box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        box.pack_end (bbox, false, false, 0);
        grid.attach (scrolled, 0, 0, 1, 1);
        grid.attach (box, 0, 1, 1, 1);
        w.add (grid);
        w.set_transient_for(_w);

        w.delete_event.connect (() => {
                w.hide();
                return true;
            });


        buttons[Buttons.ADD].clicked.connect (() => {
                Gtk.TreeIter iter;
                listmodel.append (out iter);
                listmodel.set (iter,
                               Column.NAME, "",
                               Column.LAT, cv.get_center_latitude(),
                               Column.LON, cv.get_center_longitude(),
                               Column.ZOOM, cv.get_zoom_level());
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
        view.insert_column_with_attributes (-1, "Latitude",
                                            cell, "text", Column.LAT);
        col = view.get_column(Column.LAT);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, Column.LAT, out v);
                double val = (double)v;
                string s = PosFormat.lat(val,MWP.conf.dms);
                _cell.set_property("text",s);
            });
        cell.set_property ("editable", true);

        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Longitude",
                                            cell, "text", Column.LON);
        col = view.get_column(Column.LON);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, Column.LON, out v);
                double val = (double)v;
                string s = PosFormat.lon(val,MWP.conf.dms);
                _cell.set_property("text",s);
            });
        cell.set_property ("editable", true);

        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Zoom", cell, "text", Column.ZOOM);
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                Gtk.TreeIter iter;
                listmodel.get_iter (out iter, new Gtk.TreePath.from_string (path));
                listmodel.set_value (iter, Column.ZOOM, new_text);
            });
        cell.set_property ("editable", true);

        view.button_press_event.connect( (event) => {
                if(event.button == 3) {
                    if (get_selected_iter(out miter)) {
                        GLib.Value _cell;
                        listmodel.get_value (miter, Column.NAME, out _cell);
                        mname.set_label((string)_cell);
                        menu.popup_at_pointer();
                        return true;
                    }
                }
                return false;
            });
        view.unselect_all();
        view.hover_selection = true;
    }

    private void build_mm(Champlain.View cv) {
        menu = new Gtk.Menu();
        mname = new Gtk.MenuItem.with_label ("");

        menu.add (mname);
        menu.add (new Gtk.SeparatorMenuItem ());
        mname.sensitive = false;

        var item = new Gtk.MenuItem.with_label ("Zoom to location");
        menu.add (item);
        item.sensitive = true;
        item.activate.connect (() => {
                Value v;
                listmodel.get_value(miter, Column.LAT, out v);
                double la = (double)v;
                listmodel.get_value(miter, Column.LON, out v);
                double lo = (double)v;
                listmodel.get_value(miter, Column.ZOOM, out v);
                int zoom = (int)v;
                cv.center_on(la,lo);
                if (zoom > 0)
                    cv.zoom_level = zoom;
            });

        item = new Gtk.MenuItem.with_label ("Set location from current view");
        menu.add (item);
        item.sensitive = true;
        item.activate.connect (() => {
                listmodel.set (miter,
                               Column.LAT, cv.get_center_latitude(),
                               Column.LON, cv.get_center_longitude(),
                               Column.ZOOM, cv.get_zoom_level());
            });
        item = new Gtk.MenuItem.with_label ("Delete location");
        menu.add (item);
        item.sensitive = true;
        item.activate.connect (() => {
                listmodel.remove(ref miter);
            });
        menu.show_all();
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

    public void show() {
        load_places();
        w.show_all();
    }

    public void hide() {
        w.hide();
    }

    public void load_places() {
        listmodel.clear();
        foreach(var pl in Places.points()) {
            insert(pl);
        }
    }
}
