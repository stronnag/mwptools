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

public class RadarView : Object {
    Gtk.Label label;
    Gtk.Window w;
    Gtk.ListStore listmodel;
    Gtk.Button[] buttons;
    private bool vis = false;
	private int64 last_sec = 0;

    enum Column {
        SID,
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
		CATEGORY,
		ALERT,
		ID,
        NO_COLS
    }

    enum Buttons {
        CENTRE,
        HIDE,
        CLOSE
    }

    public enum Status {
        UNDEF = 0,
        ARMED = 1,
        HIDDEN =2,
        STALE = 3,
        ADSB = 4,
        SBS = 5
    }

	const double TOTHEMOON = -9999.0;

	public static string[] status = {"Undefined", "Armed", "Hidden", "Stale", "ADS-B", "SDR"};
    public signal void vis_change(bool hidden);
    public signal void zoom_to_swarm(double lat, double lon);

    internal RadarView (Gtk.Window? _w) {
        w = new Gtk.Window();
        var scrolled = new Gtk.ScrolledWindow (null, null);
        w.set_default_size (900, 400);
        w.title = "Radar & Telemetry Tracking";
        var view = new Gtk.TreeView ();
        view.hexpand = true;
        view.vexpand = true;
        setup_treeview (view);
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
        grid.hexpand = true;
        grid.vexpand = true;
        grid.attach (scrolled, 0, 0, 1, 1);
        grid.attach (box, 0, 1, 1, 1);
        w.add (grid);
        w.set_transient_for(_w);
        w.delete_event.connect (() => {
                show_or_hide();
                return true;
            });
    }

    private string source_id(uint8 sid) {
        switch(sid) {
        case RadarSource.INAV:
            return "I";
        case RadarSource.TELEM:
            return "T";
        case RadarSource.MAVLINK:
            return "A";
        case RadarSource.SBS:
            return "S";
        }
        return "?";
    }

    private void pan_to_swarm() {
        int n = 0;
        double alat = 0;
        double alon = 0;
        Gtk.TreeIter iter;

        for(bool next=listmodel.get_iter_first(out iter); next;
            next=listmodel.iter_next(ref iter)) {
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

    private void show_number() {
        int n_rows = listmodel.iter_n_children(null);
        int stale = 0;
        int hidden = 0;
        Gtk.TreeIter iter;

        buttons[Buttons.CENTRE].sensitive = (n_rows != 0);

        for(bool next=listmodel.get_iter_first(out iter); next; next=listmodel.iter_next(ref iter)) {
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

    private bool find_entry(RadarPlot r, out Gtk.TreeIter iter) {
        bool found = false;
        for(bool next=listmodel.get_iter_first(out iter); next; next=listmodel.iter_next(ref iter)) {
            GLib.Value cell;
            listmodel.get_value (iter, Column.ID, out cell);
            var id = (uint)cell;
            if(id == r.id) {
                found = true;
                break;
            }
        }
        return found;
    }

    public void remove (RadarPlot r) {
        Gtk.TreeIter iter;
        if (find_entry(r, out iter)) {
            listmodel.remove(ref iter);
            show_number();
        }
    }

	private void set_cell_text_bg(Gtk.TreeModel model, Gtk.TreeIter iter, Gtk.CellRenderer cell, string? s) {
		Value v;
		model.get_value(iter, Column.ALERT, out v);
		var val = (uint)v;
		if ((val & RadarAlert.ALERT) == RadarAlert.ALERT) {
			cell.cell_background = "red";
			cell.cell_background_set = true;
		} else {
			cell.cell_background_set = false;
		}
		cell.set_property("text", s);
	}

	public void update (ref unowned RadarPlot r, bool verbose = false) {
		var dt = new DateTime.now_local ();
		double idm = TOTHEMOON;
		uint cse =0;
		uint8 htype;
		double hlat, hlon;
		var alert = r.alert;
		string ga_range;
		string ga_bearing;
		string ga_alt;
		string ga_speed;

		if(MWP.any_home(out htype, out hlat, out hlon)) {
			double c,d;
			Geo.csedist(hlat, hlon, r.latitude, r.longitude, out d, out c);
			idm = d*1852.0; // nm to m
			cse = (uint)c;
			if((r.source & RadarSource.M_ADSB) != 0) {
				if(MWP.conf.radar_alert_altitude > 0 && MWP.conf.radar_alert_range > 0 &&
				   r.altitude < MWP.conf.radar_alert_altitude && idm < MWP.conf.radar_alert_range) {
					r.alert = RadarAlert.ALERT;
					var this_sec = dt.to_unix();
					if(r.state > Status.STALE && this_sec >= last_sec + 2) {
						MWP.play_alarm_sound(MWPAlert.GENERAL);
						last_sec =  this_sec;
					}
                } else {
					r.alert = RadarAlert.NONE;
				}
			}
		}

		if (alert != r.alert) {
			r.alert |= RadarAlert.SET;
		}

		if(MWP.conf.max_radar_altitude > 0 && r.altitude > MWP.conf.max_radar_altitude) {
			if(verbose) {
                MWPLog.message("RADAR: Not listing %s at %.lf m\n", r.name, r.altitude);
            }
			return;
		}

        Gtk.TreeIter iter;
        var found = find_entry(r, out iter);
        if(!found) {
            listmodel.append (out iter);
            listmodel.set (iter, Column.ID,r.id);
        }

        if(r.state >= RadarView.status.length)
            r.state = Status.UNDEF;
        var stsstr = "%s / %u".printf(RadarView.status[r.state], r.lq);
		ga_range = "";
		if (idm == TOTHEMOON) {
			ga_bearing = "";
		} else {
			ga_bearing = "%u°".printf(cse);
		}

		if((r.source & RadarSource.M_ADSB) != 0) {
			ga_alt = Units.ga_alt(r.altitude);
			ga_speed = Units.ga_speed(r.speed);
			if (idm == TOTHEMOON && r.srange != 0xffffffff) {
				idm = (double)(r.srange);
			}
			if (idm != TOTHEMOON) {
				ga_range = Units.ga_range(idm);
			}
		} else {
			ga_alt = "%.0f %s".printf(Units.distance(r.altitude), Units.distance_units());
			ga_speed = "%.0f %s".printf(Units.speed(r.speed), Units.speed_units());
			if (idm != TOTHEMOON) {
				ga_range = "%.0f %s".printf(Units.distance(idm), Units.distance_units());
			}
		}

		listmodel.set (iter,
                       Column.SID, source_id(r.source),
                       Column.NAME,r.name,
                       Column.LAT, PosFormat.lat(r.latitude, MWP.conf.dms),
                       Column.LON, PosFormat.lon(r.longitude, MWP.conf.dms),
                       Column.ALT, ga_alt,
                       Column.COURSE, "%d °".printf(r.heading),
                       Column.SPEED, ga_speed,
                       Column.STATUS, stsstr);

		if(r.state == Status.ARMED || r.state == Status.ADSB || r.state == Status.SBS) {
			listmodel.set (iter, Column.LAST, r.dt.format("%T"));
        }

		var scat = CatMap.to_category(r.etype);
		listmodel.set (iter,
					   Column.RANGE, ga_range,
					   Column.BEARING, ga_bearing,
					   Column.CATEGORY, scat,
					   Column.ALERT, alert);
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
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
                                       typeof (string),
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
        view.insert_column_with_attributes (-1, "*",
                                            cell, "text",
                                            Column.SID);

        view.insert_column_with_attributes (-1, "Id",
                                            cell, "text",
                                            Column.NAME);

        var col = view.get_column(Column.NAME);
        col.set_cell_data_func(cell, (col,_cell, model, iter) => {
                Value v;
                model.get_value(iter, Column.NAME, out v);
				set_cell_text_bg(model, iter, _cell, (string)v);
			});

		cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Latitude", cell, "text", Column.LAT);

        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Longitude", cell, "text", Column.LON);

		cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Altitude", cell, "text", Column.ALT);

        cell = new Gtk.CellRendererText ();
		view.insert_column_with_attributes (-1, "Course", cell, "text", Column.COURSE);

        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Speed", cell, "text", Column.SPEED);

        cell = new Gtk.CellRendererText ();
		view.insert_column_with_attributes (-1, "Status", cell, "text", Column.STATUS);

        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Last", cell, "text", Column.LAST);

        cell = new Gtk.CellRendererText ();
		view.insert_column_with_attributes (-1, "Range", cell, "text", Column.RANGE);

        cell = new Gtk.CellRendererText ();
		view.insert_column_with_attributes (-1, "Brg.", cell, "text", Column.BEARING);

        cell = new Gtk.CellRendererText ();
		view.insert_column_with_attributes (-1, "Cat.", cell, "text", Column.CATEGORY);

        int [] widths = {2,12, 16, 16, 10, 10, 10, 12, 12, 12, 6, 4, 4};
        for (int j = Column.SID; j <= Column.CATEGORY; j++) {
            var scol =  view.get_column(j);
            if(scol!=null) {
                scol.set_min_width(7*widths[j]);
                scol.resizable = true;
                if (j == Column.SID || j == Column.NAME || j == Column.STATUS || j == Column.LAST || j == Column.RANGE)
                    scol.set_sort_column_id(j);
            }
        }
    }

    public void show_or_hide() {
        if(vis)
            w.hide();
        else
            w.show_all();
        vis = !vis;
    }
}
