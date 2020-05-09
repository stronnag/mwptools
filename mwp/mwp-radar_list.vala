

class RadarView : Object
{
    Gtk.Label label;
    Gtk.Window w;
    Gtk.ListStore listmodel;
    private bool vis = false;

    enum Column {
        ID,
        LAT,
        LON,
        ALT,
        COURSE,
        SPEED,
        STATUS,
        LAST,
        NO_COLS
    }

    internal RadarView (Gtk.Window? _w) {
        w = new Gtk.Window();
        var scrolled = new Gtk.ScrolledWindow (null, null);
        w.set_default_size (750, 300);
        w.add(scrolled);
        w.title = "Radar Data";
        var view = new Gtk.TreeView ();
        this.setup_treeview (view);
        view.expand = true;
        label = new Gtk.Label ("");
        var grid = new Gtk.Grid ();
        grid.attach (view, 0, 0, 1, 1);
        grid.attach (label, 0, 1, 1, 1);
        scrolled.add (grid);
        w.set_transient_for(_w);
        w.delete_event.connect (() => {
                show_or_hide();
                return true;
            });
    }

    private void show_number()
    {
        int n_rows = listmodel.iter_n_children(null);
        label.set_text ("Items %d".printf(n_rows));
    }

    private bool find_entry(RadarPlot r, out Gtk.TreeIter iter)
    {
        bool found = false;
        for(bool next=listmodel.get_iter_first(out iter); next;
            next=listmodel.iter_next(ref iter))
        {
            GLib.Value cell;
            listmodel.get_value (iter, Column.ID, out cell);
            var name = (string)cell;
            if(name == r.name)
            {
                found = true;
                break;
            }
        }
        return found;
    }

    public void remove (RadarPlot r)
    {
        Gtk.TreeIter iter;
        if (find_entry(r, out iter))
        {
#if LSRVAL
            listmodel.remove(iter);
#else
            listmodel.remove(ref iter);
#endif
            show_number();
        }
    }

    public void update (RadarPlot r, bool dms)
    {
        Gtk.TreeIter iter;
        var found = find_entry(r, out iter);
        if(!found)
            listmodel.append (out iter);

        string[] sts = {"Undefined", "Armed", "Hidden", "Stale", "ADS-B"};

        if(r.state >= sts.length)
            r.state = 0;
        var stsstr = "%s / %u".printf(sts[r.state], r.lq);

        listmodel.set (iter,
                       Column.ID,r.name,
                       Column.LAT, "%s".printf(PosFormat.lat(r.latitude,dms)),
                       Column.LON, "%s".printf(PosFormat.lon(r.longitude,dms)),
                       Column.ALT,"%.0f %s".printf(Units.distance(r.altitude), Units.distance_units()),
                       Column.COURSE, "%d °".printf(r.heading),
                       Column.SPEED, "%.0f %s".printf(Units.speed(r.speed), Units.speed_units()),
                       Column.STATUS, stsstr);

        if(r.state == 1 || r.state == 4)
        {
          var dt = new DateTime.now_local ();
          listmodel.set (iter, Column.LAST, dt.format("%T"));
        }
        show_number();
    }

    private void setup_treeview (Gtk.TreeView view) {

        listmodel = new Gtk.ListStore (Column.NO_COLS,
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string) );

        view.set_model (listmodel);
        var cell = new Gtk.CellRendererText ();

            /* 'weight' refers to font boldness.
             *  400 is normal.
             *  700 is bold.
             */
//        cell.set ("weight_set", true);
//        cell.set ("weight", 700);

            /*columns*/
        view.insert_column_with_attributes (-1, "Id",
                                            cell, "text",
                                            Column.ID);


        view.insert_column_with_attributes (-1, "Latitude",
                                            new Gtk.CellRendererText (),
                                            "text", Column.LAT);

        view.insert_column_with_attributes (-1, "Longitude",
                                            new Gtk.CellRendererText (),
                                            "text", Column.LON);

        view.insert_column_with_attributes (-1, "Altitude",
                                            new Gtk.CellRendererText (),
                                            "text", Column.ALT);
        view.insert_column_with_attributes (-1, "Course",
                                            new Gtk.CellRendererText (),
                                            "text", Column.COURSE);
        view.insert_column_with_attributes (-1, "Speed",
                                            new Gtk.CellRendererText (),
                                            "text", Column.SPEED);
        view.insert_column_with_attributes (-1, "Status",
                                            new Gtk.CellRendererText (),
                                            "text", Column.STATUS);

        view.insert_column_with_attributes (-1, "Last",
                                            new Gtk.CellRendererText (),
                                            "text", Column.LAST);

        int [] widths = {10, 16, 16, 10, 10, 10, 12, 12};
        for (int j = Column.ID; j < Column.NO_COLS; j++)
        {
            var scol =  view.get_column(j);
            if(scol!=null)
            {
                scol.set_min_width(7*widths[j]);
                if (j == Column.ID || j == Column.STATUS || j == Column.LAST)
                    scol.set_sort_column_id(j);
            }
        }
    }

    public void show_or_hide()
    {
        if(vis)
            w.hide();
        else
            w.show_all();

        vis = !vis;
    }
}
