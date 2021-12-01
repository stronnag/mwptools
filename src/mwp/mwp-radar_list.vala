/*
 * Copyright (C) 2020 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

class RadarView : Object
{
    Gtk.Label label;
    Gtk.Window w;
    Gtk.ListStore listmodel;
    Gtk.Button[] buttons;
    private bool vis = false;
	private int last_sec = -1;

    enum Column {
        NAME,
        LAT,
        LON,
        ALT,
        COURSE,
        SPEED,
        STATUS,
        LAST,
		RANGE,
		BEARING,
		ALERT,
		ID,
        NO_COLS
    }

    enum Buttons {
        CENTRE,
        HIDE,
        CLOSE
    }


	const uint TOTHEMOON = 0xfffffff;

	public static string[] status = {"Undefined", "Armed", "Hidden", "Stale", "ADS-B"};
    public signal void vis_change(bool hidden);
    public signal void zoom_to_swarm(double lat, double lon);

    internal RadarView (Gtk.Window? _w) {
        w = new Gtk.Window();
        var scrolled = new Gtk.ScrolledWindow (null, null);
        w.set_default_size (750, 300);
        w.title = "Radar Data";
        var view = new Gtk.TreeView ();
        setup_treeview (view);
        view.expand = true;
        label = new Gtk.Label ("");
        var grid = new Gtk.Grid ();
        scrolled.add(view);

        buttons = {
            new Gtk.Button.with_label ("Centre on swarm"),
            new Gtk.Button.with_label ("Hide symbols"),
            new Gtk.Button.with_label ("Close")
        };

        bool hidden = false;

        buttons[Buttons.HIDE].clicked.connect (() => {
                vis_change(hidden);
                if(!hidden)
                    buttons[Buttons.HIDE].label = "Show symbols";
                else
                    buttons[Buttons.HIDE].label = "Hide symbols";
                hidden = !hidden;
            });

        buttons[Buttons.CLOSE].clicked.connect (() => {
                show_or_hide();
            });

        buttons[Buttons.CENTRE].clicked.connect (() => {
                pan_to_swarm();
            });

        buttons[Buttons.CENTRE].sensitive = false;
        Gtk.ButtonBox bbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        bbox.set_layout (Gtk.ButtonBoxStyle.START);

            // The number of pixels to place between children:
        bbox.set_spacing (5);

            // Add buttons to our ButtonBox:
        foreach (unowned Gtk.Button button in buttons) {
            bbox.add (button);
        }

        Gtk.Box box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        box.pack_start (label, true, false, 0);
        box.pack_end (bbox, false, false, 0);

        grid.attach (scrolled, 0, 0, 1, 1);
        grid.attach (box, 0, 1, 1, 1);
        w.add (grid);
        w.set_transient_for(_w);
        w.delete_event.connect (() => {
                show_or_hide();
                return true;
            });
    }

    private void pan_to_swarm()
    {
        int n = 0;
        double alat = 0;
        double alon = 0;
        Gtk.TreeIter iter;

        for(bool next=listmodel.get_iter_first(out iter); next;
            next=listmodel.iter_next(ref iter))
        {
            GLib.Value cell;
            listmodel.get_value (iter, Column.LAT, out cell);
            var dpos = (double)cell;
            alat += dpos;
            listmodel.get_value (iter, Column.LON, out cell);
            dpos = (double)cell;
            alon += dpos;
            n++;
        }
        if(n != 0) {
            alat /= n;
            alon /= n;
            zoom_to_swarm(alat, alon);
        }
    }

    private void show_number()
    {
        int n_rows = listmodel.iter_n_children(null);
        int stale = 0;
        int hidden = 0;
        Gtk.TreeIter iter;

        buttons[Buttons.CENTRE].sensitive = (n_rows != 0);

        for(bool next=listmodel.get_iter_first(out iter); next;
            next=listmodel.iter_next(ref iter))
        {
            GLib.Value cell;
            listmodel.get_value (iter, Column.STATUS, out cell);
            var status = (string)cell;
            if(status.has_prefix("Stale"))
                stale++;
            if(status.has_prefix("Hidden"))
                hidden++;
        }
        var sb = new StringBuilder("Targets: ");
        int live = n_rows - stale - hidden;
        sb.append_printf("%d", n_rows);
        if (live > 0 && (stale+hidden) > 0)
            sb.append_printf("\tLive: %d", live);
        if (stale > 0)
            sb.append_printf("\tStale: %d", stale);
        if (hidden > 0)
            sb.append_printf("\tHidden: %d", hidden);

        label.set_text (sb.str);
    }

    private bool find_entry(RadarPlot r, out Gtk.TreeIter iter)
    {
        bool found = false;
        for(bool next=listmodel.get_iter_first(out iter); next;
            next=listmodel.iter_next(ref iter))
        {
            GLib.Value cell;
            listmodel.get_value (iter, Column.ID, out cell);
            var id = (uint)cell;
            if(id == r.id)
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
            listmodel.remove(ref iter);
            show_number();
        }
    }

    public bool update (RadarPlot r, bool verbose = false)
    {
		if(MWP.conf.max_radar_altitude > 0 && r.altitude > MWP.conf.max_radar_altitude) {
			if(verbose) {
                MWPLog.message("RADAR: Not listing %s at %.lf m\n", r.name, r.altitude);
            }
			return false;
		}

        Gtk.TreeIter iter;
        var found = find_entry(r, out iter);
        if(!found)
        {
            listmodel.append (out iter);
            listmodel.set (iter, Column.ID,r.id);
        }

        if(r.state >= RadarView.status.length)
            r.state = 0;
        var stsstr = "%s / %u".printf(RadarView.status[r.state], r.lq);

        listmodel.set (iter,
                       Column.NAME,r.name,
                       Column.LAT, r.latitude,
                       Column.LON, r.longitude,
                       Column.ALT, "%.0f %s".printf(Units.distance(r.altitude), Units.distance_units()),
                       Column.COURSE, "%d °".printf(r.heading),
                       Column.SPEED, "%.0f %s".printf(Units.speed(r.speed), Units.speed_units()),
                       Column.STATUS, stsstr);


		var dt = new DateTime.now_local ();
		if(r.state == 1 || r.state == 4) {
			listmodel.set (iter, Column.LAST, dt.format("%T"));
        }

		uint idm = TOTHEMOON;
		uint cse =0;
		uint8 htype;
		double hlat, hlon;
		bool alert = false;

		if(MWP.any_home(out htype, out hlat, out hlon)) {
			double c,d;
			Geo.csedist(hlat, hlon, r.latitude, r.longitude, out d, out c);
			idm = (uint)(d*1852); // nm to m
			cse = (uint)c;
			if(MWP.conf.radar_alert_altitude > 0 && MWP.conf.radar_alert_range > 0 &&
			   r.altitude < MWP.conf.radar_alert_altitude && idm < MWP.conf.radar_alert_range) {
				alert = true;
				var this_sec = dt.get_second();
				if(this_sec != last_sec) {
					MWP.play_alarm_sound(MWPAlert.GENERAL);
					last_sec =  this_sec;
				}
			}
		}
		listmodel.set (iter, Column.RANGE, idm, Column.BEARING, cse, Column.ALERT, alert);
		show_number();
		return alert;
    }

    private void setup_treeview (Gtk.TreeView view) {

        listmodel = new Gtk.ListStore (Column.NO_COLS,
                                       typeof (string),
                                       typeof (double),
                                       typeof (double),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (uint),
                                       typeof (uint),
                                       typeof (uint),
									   typeof (uint));

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
                                            Column.NAME);

        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Latitude",
                                            cell, "text", Column.LAT);
        var col = view.get_column(Column.LAT);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, Column.LAT, out v);
                double val = (double)v;
                string s = PosFormat.lat(val, MWP.conf.dms);
                _cell.set_property("text",s);
            });


        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Longitude", cell, "text", Column.LON);
        col = view.get_column(Column.LON);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, Column.LON, out v);
                double val = (double)v;
                string s = PosFormat.lon(val,MWP.conf.dms);
                _cell.set_property("text",s);
            });

        view.insert_column_with_attributes (-1, "Altitude", new Gtk.CellRendererText (),
                                            "text", Column.ALT);
        view.insert_column_with_attributes (-1, "Course", new Gtk.CellRendererText (),
                                            "text", Column.COURSE);
        view.insert_column_with_attributes (-1, "Speed", new Gtk.CellRendererText (),
                                            "text", Column.SPEED);
        view.insert_column_with_attributes (-1, "Status", new Gtk.CellRendererText (),
                                            "text", Column.STATUS);

        view.insert_column_with_attributes (-1, "Last", new Gtk.CellRendererText (),
                                            "text", Column.LAST);
        cell = new Gtk.CellRendererText ();
		view.insert_column_with_attributes (-1, "Range", cell, "text", Column.RANGE);
        col = view.get_column(Column.RANGE);
        col.set_cell_data_func(cell, (col, _cell, model, iter) => {
                Value v;
                model.get_value(iter, Column.RANGE, out v);
                uint val = (uint)v;
				string s = "";
				if (val != TOTHEMOON) {
					s = "%.0f %s".printf(Units.distance(val), Units.distance_units());
				}
                model.get_value(iter, Column.ALERT, out v);
                val = (uint)v;
				if (val == 1) {
					_cell.cell_background = "red";
					_cell.cell_background_set = true;
				} else {
					_cell.cell_background_set = false;
				}
                _cell.set_property("text", s);
            });
        cell = new Gtk.CellRendererText ();
		view.insert_column_with_attributes (-1, "Bearing", cell, "text", Column.BEARING);
        col = view.get_column(Column.BEARING);
        col.set_cell_data_func(cell, (col, _cell, model, iter) => {
                Value v;
                model.get_value(iter, Column.RANGE, out v);
                uint val = (uint)v;
				string s = "";
				if (val != TOTHEMOON) {
					model.get_value(iter, Column.BEARING, out v);
					val = (uint)v;
					s = "%u°".printf(val);
				}
                _cell.set_property("text",s);
            });

        int [] widths = {12, 16, 16, 10, 10, 10, 12, 12, 12, 6};
        for (int j = Column.NAME; j <= Column.RANGE; j++)
        {
            var scol =  view.get_column(j);
            if(scol!=null)
            {
                scol.set_min_width(7*widths[j]);
                scol.resizable = true;
                if (j == Column.NAME || j == Column.STATUS || j == Column.LAST || j == Column.RANGE)
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
