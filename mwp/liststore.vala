/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
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

public class ListBox : GLib.Object
{
    private const int SPEED_CONV = 100;
    private const int ALT_CONV = 100;
    private const int POS_CONV = 10000000;

    public enum WY_Columns
    {
        IDX,
            TYPE,
            LAT,
            LON,
            ALT,
            INT1,
            INT2,
            INT3,
            MARKER,
            ACTION,
            TIP,
            N_COLS
    }

    private Gtk.Menu menu;
    public Gtk.TreeView view;
    public Gtk.ListStore list_model;
    private MWPlanner mp;
    private bool purge;
    private Gtk.MenuItem shp_item;
    private Gtk.MenuItem up_item;
    private Gtk.MenuItem down_item;
    private Gtk.MenuItem del_item;
    private Gtk.MenuItem alts_item;
    private Gtk.MenuItem altz_item;
    private Gtk.MenuItem delta_item;
    private Gtk.MenuItem speedz_item;
    private Gtk.MenuItem speedv_item;
    private ShapeDialog shapedialog;
    private DeltaDialog deltadialog;
    private SpeedDialog speeddialog;
    private AltDialog altdialog;
    public int lastid {get; private set; default= 0;}
    public bool have_rth {get; private set; default= false;}

    public ListBox()
    {
        purge=false;
        MWPlanner.conf.settings_update.connect((s) => {
                if(s == "display-distance" ||
                   s == "default-nav-speed")
                    calc_mission();
            });
    }

    public void import_mission(Mission ms)
    {
        Gtk.TreeIter iter;

        list_model.clear();
        lastid = 0;
        have_rth = false;
        foreach (MissionItem m in ms.get_ways())
        {
            list_model.append (out iter);
            string no;
            double m1 = 0;
            switch (m.action)
            {
                case MSP.Action.RTH:
                    no="";
                    m1 = ((double)m.param1);
                    have_rth = true;
                    break;
                default:
                    lastid++;
                    no = lastid.to_string();
                    if (m.action == MSP.Action.WAYPOINT)
                        m1 = ((double)m.param1 / SPEED_CONV);
                    else
                        m1 = ((double)m.param1);
                    break;
            }
            list_model.set (iter,
                            WY_Columns.IDX, no,
                            WY_Columns.TYPE, MSP.get_wpname(m.action),
                            WY_Columns.LAT, m.lat,
                            WY_Columns.LON, m.lon,
                            WY_Columns.ALT, m.alt,
                            WY_Columns.INT1, m1,
                            WY_Columns.INT2, m.param2,
                            WY_Columns.INT3, m.param3,
                            WY_Columns.ACTION, m.action);
        }
        calc_mission();
    }

    public  MSP_WP[] to_wps(bool cf = false, bool fixwing = false)
    {
        Gtk.TreeIter iter;
        MSP_WP[] wps =  {};
        var n = 0;
        for(bool next=list_model.get_iter_first(out iter);next;next=list_model.iter_next(ref iter))
        {
            GLib.Value cell;
            list_model.get_value (iter, WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            if(typ != MSP.Action.UNASSIGNED)
            {
                var w = MSP_WP();
                n++;
                w.action = typ;
                list_model.get_value (iter, WY_Columns.IDX, out cell);
                w.wp_no = n;
                list_model.get_value (iter, WY_Columns.LAT, out cell);
                w.lat = (int32)Math.lround(((double)cell) * POS_CONV);
                list_model.get_value (iter, WY_Columns.LON, out cell);
                w.lon = (int32)Math.lround(((double)cell) * POS_CONV);
                list_model.get_value (iter, WY_Columns.ALT, out cell);
                w.altitude = (int32)(((int)cell) * ALT_CONV);
                list_model.get_value (iter, WY_Columns.INT1, out cell);
                var tint = (double)cell;
                if(w.action == MSP.Action.WAYPOINT)
                    w.p1 = (int16)(tint*SPEED_CONV);
                else
                    w.p1 = (int16)tint;
                list_model.get_value (iter, WY_Columns.INT2, out cell);
                tint = (int)cell;
                w.p2 = (uint16)tint;
                list_model.get_value (iter, WY_Columns.INT3, out cell);
                tint = (int)cell;
                w.p3 = (uint16)tint;
                w.flag = 0;
                if(cf)
                {
                    switch(typ)
                    {
                        case MSP.Action.POSHOLD_TIME:
                        case MSP.Action.POSHOLD_UNLIM:
                        case MSP.Action.LAND:
                            MWPLog.message("Downgrade WP %s\n",
                                           typ.to_string());
                            w.action =  MSP.Action.WAYPOINT;
                            w.p1 = 0;
                            w.p2 = w.p3 = 0;
                            break;
                        case MSP.Action.SET_POI:
                        case MSP.Action.SET_HEAD:
                        case MSP.Action.JUMP:
                            MWPLog.message("Remove WP %s\n", typ.to_string());

                            n--;
                            continue;
                    }
                }
                if(fixwing && (typ == MSP.Action.RTH))
                {
                    MWPLog.message("Remove Land from WP RTH\n");
                    w.p1 = 0;
                }
                wps += w;
            }
        }
        if(wps.length > 0)
            wps[wps.length-1].flag = 0xa5;
        return wps;
    }

    public bool validate_mission(MissionItem []wp, uint8 wp_flag)
    {
        int n_rows = list_model.iter_n_children(null);
        bool res = true;

        if(n_rows == wp.length)
        {
            int n = 0;
            var ms = to_mission();
            foreach(MissionItem  m in ms.get_ways())
            {
                if ((m.action != wp[n].action) ||
                    (Math.fabs(m.lat - wp[n].lat) > 1e-6) ||
                    (Math.fabs(m.lon - wp[n].lon) > 1e-6) ||
                    (m.alt != wp[n].alt) ||
                    (m.param1 != wp[n].param1) ||
                    (m.param2 != wp[n].param2) ||
                    (m.param3 != wp[n].param3))
                {
                    res = false;
                    break;
                }
                n++;
            }
        }
        else
        {
            res = false;
        }
        return res;
    }

    public Mission to_mission()
    {
        Gtk.TreeIter iter;
        int n = 0;
        MissionItem[] arry = {};
        var ms = new Mission();

        for(bool next=list_model.get_iter_first(out iter);next;next=list_model.iter_next(ref iter))
        {
            GLib.Value cell;
            list_model.get_value (iter, WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            if(typ != MSP.Action.UNASSIGNED)
            {
                var m = MissionItem();
                n++;
                m.action = typ;
                m.no = n;
                list_model.get_value (iter, WY_Columns.LAT, out cell);
                m.lat = (double)cell;
                list_model.get_value (iter, WY_Columns.LON, out cell);
                m.lon = (double)cell;
                list_model.get_value (iter, WY_Columns.ALT, out cell);
                m.alt = (int)cell;
                list_model.get_value (iter, WY_Columns.INT1, out cell);
                if(typ == MSP.Action.WAYPOINT)
                    m.param1 = (int)(SPEED_CONV*(double)cell);
                else
                    m.param1 = (int)((double)cell);
                list_model.get_value (iter, WY_Columns.INT2, out cell);
                m.param2 = (int)cell;
                list_model.get_value (iter, WY_Columns.INT3, out cell);
                m.param3 = (int)cell;
                arry += m;
            }
        }
        ms.zoom = mp.view.get_zoom_level();
        ms.cy = mp.view.get_center_latitude();
        ms.cx = mp.view.get_center_longitude();
        ms.set_ways(arry);
        return ms;
    }

    public void change_marker(string typ, int flag=0)
    {
        foreach (var t in get_selected_refs())
        {
            Gtk.TreeIter iter;
            var path = t.get_path ();
            list_model.get_iter (out iter, path);
            update_marker_type(iter, typ, flag);
        }
    }

    private int get_user_alt()
    {
        Gtk.Entry ent = mp.builder.get_object ("entry1") as Gtk.Entry;
        var ualt = int.parse(ent.get_text());
        return ualt;
    }

    private void update_marker_type(Gtk.TreeIter iter, string typ, int flag)
    {
        Value val,val1;
        var action = MSP.lookup_name(typ);
        list_model.get_value (iter, WY_Columns.ACTION, out val);
        var old = (MSP.Action)val;
        if (old != action)
        {
            list_model.set_value (iter, WY_Columns.ACTION, action);
            list_model.set_value (iter, WY_Columns.TYPE, typ);
            list_model.get_value (iter, WY_Columns.MARKER, out val);
            var mk =  (Champlain.Label)val;
            list_model.get_value (iter, WY_Columns.IDX, out val1);
            var no = (string)val1;
            mp.markers.change_label(mk, old, action, no);
            switch (action)
            {
                case MSP.Action.JUMP:
                    list_model.set_value (iter, WY_Columns.LAT, 0.0);
                    list_model.set_value (iter, WY_Columns.LON, 0.0);
                    list_model.set_value (iter, WY_Columns.ALT, 0);
                    list_model.set_value (iter, WY_Columns.INT1, 0.0);
                    list_model.set_value (iter, WY_Columns.INT2, 0);
                    break;
                case MSP.Action.POSHOLD_TIME:
                    Gtk.Entry ent = mp.builder.get_object ("entry2") as Gtk.Entry;
                    var ltime = int.parse(ent.get_text());
                    list_model.set_value (iter, WY_Columns.INT1, (double)ltime);
                    break;
                case MSP.Action.RTH:
                    list_model.set_value (iter, WY_Columns.LAT, 0.0);
                    list_model.set_value (iter, WY_Columns.LON, 0.0);
                    list_model.set_value (iter, WY_Columns.ALT, 0);
                    list_model.set_value (iter, WY_Columns.INT1, flag);
                    have_rth = true;
                    break;
                case MSP.Action.LAND:
                    list_model.set_value (iter, WY_Columns.ALT, 0);
                    break;
                case MSP.Action.SET_HEAD:
                    list_model.set_value (iter, WY_Columns.LAT, 0.0);
                    list_model.set_value (iter, WY_Columns.LON, 0.0);
                    list_model.set_value (iter, WY_Columns.ALT, 0);
                    break;
                default:
                    if(action != MSP.Action.WAYPOINT)
                        list_model.set_value (iter, WY_Columns.INT1, 0.0);
                    else
                    {
                        Value cell;
                        list_model.get_value (iter, WY_Columns.LAT, out cell);
                        double wlat = (double)cell;
                        list_model.get_value (iter, WY_Columns.LON, out cell);
                        double wlon = (double)cell;
                        if (wlat == 0.0)
                            list_model.set_value (iter, WY_Columns.LAT,
                                                  mp.view.get_center_latitude());
                        if (wlon == 0.0)
                            list_model.set_value (iter, WY_Columns.LON,
                                                  mp.view.get_center_longitude());
                    }
                    list_model.set_value (iter, WY_Columns.INT2, 0);
                    list_model.set_value (iter, WY_Columns.INT3, 0);
                    break;
            }
            renumber_steps(list_model);
        }
    }

    public void create_view(MWPlanner _mp)
    {
        make_menu();

        mp = _mp;

        shapedialog = new ShapeDialog(mp.builder);
        deltadialog = new DeltaDialog(mp.builder);
        speeddialog = new SpeedDialog(mp.builder);
        altdialog = new AltDialog(mp.builder);

            // Combo, Model:
        Gtk.ListStore combo_model = new Gtk.ListStore (1, typeof (string));
        Gtk.TreeIter iter;

        for(var n = MSP.Action.WAYPOINT; n <= MSP.Action.LAND; n += 1)
        {
            combo_model.append (out iter);
            combo_model.set (iter, 0, MSP.get_wpname(n));
        }

        list_model = new Gtk.ListStore (WY_Columns.N_COLS,
                                        typeof (string),
                                        typeof (string),
                                        typeof (double),
                                        typeof (double),
                                        typeof (int),
                                        typeof (double),
                                        typeof (int),
                                        typeof (int),
                                        typeof (Champlain.Label),
                                        typeof (MSP.Action),
                                        typeof (string)
                                        );

        view = new Gtk.TreeView.with_model (list_model);

        view.set_tooltip_column(WY_Columns.TIP);

        var sel = view.get_selection();

        sel.set_mode(Gtk.SelectionMode.MULTIPLE);

        sel.changed.connect(() => {
                if (sel.count_selected_rows () == 1)
                {
                    update_selected_cols();
                }
            });


        Gtk.CellRenderer cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "ID", cell, "text", WY_Columns.IDX);

        Gtk.TreeViewColumn column = new Gtk.TreeViewColumn ();
        column.set_title ("Type");
        view.append_column (column);

        Gtk.CellRendererCombo combo = new Gtk.CellRendererCombo ();
        combo.set_property ("editable", true);
        combo.set_property ("model", combo_model);
        combo.set_property ("text-column", 0);
        combo.set_property ("has-entry", false);
        column.pack_start (combo, false);
        column.add_attribute (combo, "text", 1);
        combo.changed.connect((path, iter_new) => {
                Gtk.TreeIter iter_val;
                Value val;
                combo_model.get_value (iter_new, 0, out val);
                var typ = (string)val;
                list_model.get_iter (out iter_val, new Gtk.TreePath.from_string (path));
                update_marker_type(iter_val, typ, 0);
            });

        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Lat.",
                                            cell,
                                            "text", WY_Columns.LAT);

        var col = view.get_column(WY_Columns.LAT);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, WY_Columns.LAT, out v);
                double val = (double)v;
                string s = PosFormat.lat(val,MWPlanner.conf.dms);
                _cell.set_property("text",s);
            });

        cell.set_property ("editable", true);
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.LAT,-90.0,90.0,false);
            });


        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Lon.",
                                            cell,
                                            "text", WY_Columns.LON);
        col = view.get_column(WY_Columns.LON);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, WY_Columns.LON, out v);
                double val = (double)v;
                string s = PosFormat.lon(val,MWPlanner.conf.dms);
                _cell.set_property("text",s);
            });

        cell.set_property ("editable", true);

        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.LON,-180.0,180.0,false);
            });


        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Alt.",
                                            cell,
                                            "text", WY_Columns.ALT);

        col = view.get_column(WY_Columns.ALT);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, WY_Columns.ALT, out v);
                double val = (int)v;
                long l = Math.lround(Units.distance(val));
                string s = "%ld".printf(l);
                _cell.set_property("text",s);
            });

        cell.set_property ("editable", true);
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.ALT,0.0,1000.0,true);
            });


        cell = new Gtk.CellRendererText ();
        cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "P1",
                                            cell,
                                            "text", WY_Columns.INT1);
        col = view.get_column(WY_Columns.INT1);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                string s;
                Value icell;
                Value v;
                model.get_value(iter, WY_Columns.INT1, out v);
                model.get_value (iter, WY_Columns.ACTION, out icell);
                var typ = (MSP.Action)icell;
                if (typ == MSP.Action.WAYPOINT)
                {
                    double val = (double)v;
                    s = "%.1f".printf(Units.speed(val));
                }
                else
                    s = "%.0f".printf((double)v);
                _cell.set_property("text",s);
            });

        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {

                GLib.Value icell;
                Gtk.TreeIter iiter;
                list_model.get_iter (out iiter, new Gtk.TreePath.from_string (path));
                list_model.get_value (iiter, WY_Columns.ACTION, out icell);
                var typ = (MSP.Action)icell;
                if (typ == MSP.Action.JUMP)
                {
                     list_model.get_value (iiter, WY_Columns.IDX, out icell);
                     var iwp = int.parse((string)icell);
                     var nwp = int.parse(new_text);
                     if(nwp < 1 || nwp >= iwp)
                         return;
                }
                list_validate(path,new_text,
                              WY_Columns.INT1,-1,65536.0,true);
            });


        cell = new Gtk.CellRendererText ();
        cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "P2",
                                            cell,
                                            "text", WY_Columns.INT2);
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.INT2,-1,65536.0,true);
            });


        cell = new Gtk.CellRendererText ();
        cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "P3",
                                            cell,
                                            "text", WY_Columns.INT3);
        // Min val is -1 because only jump uses this.
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.INT3,-1,65536.0,true);
            });

        view.set_headers_visible (true);
        view.set_reorderable(true);
        list_model.row_deleted.connect((path,iter) => {
                if (purge == false)
                {
                    renumber_steps(list_model);
                }
            });
        list_model.rows_reordered.connect((path,iter,rlist) => {
                renumber_steps(list_model);
            });

        view.button_press_event.connect( event => {
                if(event.button == 3)
                {
                    var time = event.time;
/*
                    Value val;
                    list_model.get_iter_first(out _iter);
                    list_model.get_value (_iter, WY_Columns.ACTION, out val);
                    shp_item.sensitive=((MSP.Action)val == MSP.Action.SET_POI);
                        // remove ins, del as well
                        */
                    if(sel.count_selected_rows () == 0)
                    {
                        del_item.sensitive = delta_item.sensitive =
                            alts_item.sensitive = altz_item.sensitive =
                            speedv_item.sensitive = speedz_item.sensitive =
                            false;
                    }
                    else
                    {
                        del_item.sensitive = delta_item.sensitive =
                            alts_item.sensitive = altz_item.sensitive =
                            speedv_item.sensitive = speedz_item.sensitive =
                            true;
                    }

                    if(sel.count_selected_rows () == 1)
                    {
                        Value val;
                        Gtk.TreeIter iv;
                        up_item.sensitive = down_item.sensitive = true;
                        var rows = sel.get_selected_rows(null);
                        list_model.get_iter (out iv, rows.nth_data(0));
                        list_model.get_value (iv, WY_Columns.ACTION, out val);
                        shp_item.sensitive=((MSP.Action)val == MSP.Action.SET_POI);
                    }
                    else
                    {
                        up_item.sensitive = down_item.sensitive = false;
                    }
                    menu.popup(null, null, null, 0, time);
                    return true;
                }
                return false;
            });

        foreach (var c in view.get_columns())
            c.set_resizable(true);
    }

    private void list_validate(string path, string new_text, int colno,
                               double minval, double maxval, bool as_int)
    {
        Gtk.TreeIter iter_val;
        var list_model = view.get_model() as Gtk.ListStore;

        list_model.get_iter (out iter_val, new Gtk.TreePath.from_string (path));

        double d;
        switch(colno)
        {
            case  WY_Columns.LAT:
                d = InputParser.get_latitude(new_text);
                break;
            case  WY_Columns.LON:
                d = InputParser.get_longitude(new_text);
                break;
            case  WY_Columns.ALT:
                d = InputParser.get_scaled_real(new_text);
                break;
            case WY_Columns.INT1:
                Value icell;
                list_model.get_value (iter_val, WY_Columns.ACTION, out icell);
                var typ = (MSP.Action)icell;
                if (typ == MSP.Action.WAYPOINT)
                    d = InputParser.get_scaled_real(new_text,"s");
                else
                    d = get_locale_double(new_text);
                break;
            default:
                d = get_locale_double(new_text);
                break;
        }

        if (d <= maxval && d >= minval)
        {
            if (as_int == true)
            {
                list_model.set_value (iter_val, colno, d);
            }
            else
            {
                list_model.set_value (iter_val, colno, d);
                mp.markers.add_list_store(this);
            }
            calc_mission();
        }
    }

    private void renumber_steps(Gtk.ListStore ls)
    {
        int n = 1;
        Gtk.TreeIter iter;
        bool need_del = false;
        have_rth = false;
        purge = true;
        for(bool next=ls.get_iter_first(out iter);next;next=ls.iter_next(ref iter))
        {
            if(need_del)
            {
                list_model.remove(iter);
                lastid--;
            }
            else
            {
                GLib.Value cell;
                list_model.get_value (iter, WY_Columns.ACTION, out cell);
                MSP.Action act = (MSP.Action)cell;
                switch (act)
                {
                    case MSP.Action.RTH:
                        ls.set_value (iter, WY_Columns.IDX, "");
                        need_del = true;
                        have_rth = true;
                        break;

                    default:
                        ls.set_value (iter, WY_Columns.IDX, n);
                        n += 1;
                        if(act == MSP.Action.POSHOLD_UNLIM)
                            need_del = true;
                        break;
                }
            }
        }
        purge = false;
            /* rebuild the map */
        int n_rows = list_model.iter_n_children(null);

            /* if there is just one item, and it's RTH, remove that too */
        if(n_rows == 1)
        {
            Value val;
            list_model.get_iter_first (out iter);
            list_model.get_value (iter, WY_Columns.ACTION, out val);
            MSP.Action act = (MSP.Action)val;
            if(act ==  MSP.Action.RTH)
            {
                have_rth = false;
                lastid--;
                list_model.remove(iter);
            }
        }
        mp.markers.add_list_store(this);
        calc_mission();
    }


    private void update_selected_cols()
    {
        Gtk.TreeIter iter;
        var sel = view.get_selection ();

        if (sel != null)
        {
            var rows = sel.get_selected_rows(null);
            list_model.get_iter (out iter, rows.nth_data(0));
            Value val;
            list_model.get_value (iter, WY_Columns.ACTION, out val);
            MSP.Action act = (MSP.Action)val;
            string [] ctitles = {};

            switch (act)
            {
                case MSP.Action.WAYPOINT:
                    ctitles = {"Lat","Lon","Alt","Spd","",""};
                    break;
                case MSP.Action.POSHOLD_UNLIM:
                case MSP.Action.LAND:
                    ctitles = {"Lat","Lon","Alt","","",""};
                    break;
                case MSP.Action.POSHOLD_TIME:
                    ctitles = {"Lat","Lon","Alt","Secs","",""};
                    break;
                case MSP.Action.RTH:
                    ctitles = {"","","Alt","Land","",""};
                    break;
                case MSP.Action.SET_POI:
                    ctitles = {"Lat","Lon","","","",""};
                    break;
                case MSP.Action.JUMP:
                    ctitles = {"","","","WP#","Rpt",""};
                    break;
                case MSP.Action.SET_HEAD:
                    ctitles = {"","","","Head","",""};
                    break;
            }
            var n = 2;
            foreach (string s in ctitles)
            {
                var col = view.get_column(n);
                col.set_title(s);
                n++;
            }
        }
    }


    private void show_item(string s)
    {
        Gtk.TreeIter iter;
        var sel = view.get_selection ();
        if (sel != null)
        {
            Gtk.TreeIter step;
            var rows = sel.get_selected_rows(null);
            list_model.get_iter (out iter, rows.nth_data(0));
            switch(s)
            {
                case "Up":
                    step = iter;
                    list_model.iter_previous(ref step);
                    list_model.move_before(ref iter, step);
                    break;
                case "Down":
                    step = iter;
                    list_model.iter_next(ref step);
                    list_model.move_after(ref iter,step);
                    break;
            }
            calc_mission();
        }
    }

    private  Gtk.TreeRowReference[] get_selected_refs()
    {
        var sel = view.get_selection();
        var rows = sel.get_selected_rows(null);
        var list_model = view.get_model() as Gtk.ListStore;

        Gtk.TreeRowReference[] trefs = {};
        foreach (var r in rows) {
            trefs += new Gtk.TreeRowReference (list_model, r);
        }
        return trefs;
    }

    public void menu_delete()
    {
        foreach (var t in get_selected_refs())
        {
            Gtk.TreeIter iter;
            var path = t.get_path ();
            list_model.get_iter (out iter, path);
            list_model.remove(iter);
            lastid--;
        }
        calc_mission();
    }

    public void menu_insert()
    {
        insert_item(MSP.Action.UNASSIGNED,
                    mp.view.get_center_latitude(),
                    mp.view.get_center_longitude());
        calc_mission();
    }

    public void insert_item(MSP.Action typ, double lat, double lon)
    {
        Gtk.TreeIter iter;
        var dalt = get_user_alt();
        lastid++;
        list_model.append(out iter);
        list_model.set (iter,
                        WY_Columns.IDX, lastid.to_string(),
                        WY_Columns.TYPE, MSP.get_wpname(typ),
                        WY_Columns.LAT, lat,
                        WY_Columns.LON, lon,
                        WY_Columns.ALT, dalt,
                        WY_Columns.ACTION, typ );
        var is = list_model.iter_is_valid (iter);
        if (is == true)
            mp.markers.add_single_element(this,  iter, false);
        else
            mp.markers.add_list_store(this);
    }

    private void add_shapes()
    {
        ShapeDialog.ShapePoint[] pts;
        Gtk.TreeIter iter;
        Value val;
        double lat,lon;

        for(bool next=list_model.get_iter_first(out iter);
            next;
            next=list_model.iter_next(ref iter))
        {
            list_model.get_value (iter, WY_Columns.ACTION, out val);
            if ((MSP.Action)val == MSP.Action.SET_POI)
                break;
        }

//        list_model.get_iter_first(out iter);
        list_model.get_value (iter, WY_Columns.LAT, out val);
        lat = (double)val;
        list_model.get_value (iter, WY_Columns.LON, out val);
        lon = (double)val;
        pts = shapedialog.get_points(lat,lon);
        foreach (ShapeDialog.ShapePoint p in pts)
        {
            insert_item(MSP.Action.WAYPOINT, p.lat, p.lon);
        }
        calc_mission();
    }

    private void do_deltas()
    {
        double dlat, dlon;
        int dalt;

        if(deltadialog.get_deltas(out dlat, out dlon, out dalt) == true)
        {
            if(dlat != 0.0 || dlon != 0.0 || dalt != 0)
            {
                 foreach (var t in get_selected_refs())
                 {
                     Gtk.TreeIter iter;
                     GLib.Value cell;
                     var path = t.get_path ();
                     list_model.get_iter (out iter, path);

                     list_model.get_value (iter, WY_Columns.TYPE, out cell);
                     var act = (MSP.Action)cell;
                     if (act == MSP.Action.RTH ||
                         act == MSP.Action.JUMP ||
                         act == MSP.Action.SET_HEAD)
                         continue;

                     if(dlat != 0.0)
                     {
                         list_model.get_value (iter, WY_Columns.LAT, out cell);
                         var val = (double)cell;
                         val += dlat;
                         list_model.set_value (iter, WY_Columns.LAT, val);
                     }

                     if(dlon != 0.0)
                     {
                         list_model.get_value (iter, WY_Columns.LON, out cell);
                         var val = (double)cell;
                         val += dlon;
                             list_model.set_value (iter, WY_Columns.LON, val);
                     }

                     if(dalt != 0)
                     {
                         list_model.get_value (iter, WY_Columns.ALT, out cell);
                         var val = (int)cell;
                         val += dalt;
                         list_model.set_value (iter, WY_Columns.ALT, val);
                     }
                 }
                 renumber_steps(list_model);
            }
        }
    }

    private void make_menu()
    {
        menu =   new Gtk.Menu ();
        Gtk.MenuItem item;

        up_item = new Gtk.MenuItem.with_label ("Move Up");
        up_item.activate.connect (() => {
                show_item("Up");
            });
        menu.add (up_item);

        down_item = new Gtk.MenuItem.with_label ("Move Down");
        down_item.activate.connect (() => {
                show_item("Down");
            });
        menu.add (down_item);

        del_item = new Gtk.MenuItem.with_label ("Delete");
        del_item.activate.connect (() => {
                menu_delete();
            });
        menu.add (del_item);

        item = new Gtk.MenuItem.with_label ("Insert");
        item.activate.connect (() => {
                menu_insert();
            });
        menu.add (item);

        alts_item = new Gtk.MenuItem.with_label ("Set all altitudes");
        alts_item.activate.connect (() => {
                set_alts(true);
            });
        menu.add (alts_item);

        altz_item = new Gtk.MenuItem.with_label ("Set zero value altitudes");
        altz_item.activate.connect (() => {
                set_alts(false);
            });
        menu.add (altz_item);

        speedv_item = new Gtk.MenuItem.with_label ("Set all leg speeds");
        speedv_item.activate.connect (() => {
                set_speeds(true);
            });
        menu.add (speedv_item);

        speedz_item = new Gtk.MenuItem.with_label ("Set zero leg speeds");
        speedz_item.activate.connect (() => {
                set_speeds(false);
            });
        menu.add (speedz_item);

        shp_item = new Gtk.MenuItem.with_label ("Add shape");
        shp_item.activate.connect (() => {
                add_shapes();
            });
        menu.add (shp_item);
        shp_item.sensitive=false;

        delta_item = new Gtk.MenuItem.with_label ("Delta updates");
        delta_item.activate.connect (() => {
                do_deltas();
            });
        menu.add (delta_item);

        item = new Gtk.MenuItem.with_label ("Clear Mission");
        item.activate.connect (() => {
                clear_mission();
            });
        menu.add (item);
        menu.show_all();
    }

    public void set_alts(bool flag)
    {
        double dalt;

        if(altdialog.get_alt(out dalt) == true)
        {
            foreach (var t in get_selected_refs())
            {
                Gtk.TreeIter iter;
                GLib.Value cell;
                var path = t.get_path ();
                list_model.get_iter (out iter, path);
                list_model.get_value (iter, WY_Columns.ACTION, out cell);
                var act = (MSP.Action)cell;
                if (act == MSP.Action.RTH ||
                    act == MSP.Action.JUMP ||
                    act == MSP.Action.SET_POI ||
                    act == MSP.Action.SET_HEAD)
                    continue;
                if(flag == false)
                {
                    list_model.get_value (iter, WY_Columns.ALT, out cell);
                    if ((int)cell != 0)
                        continue;
                }
                list_model.set_value (iter, WY_Columns.ALT, dalt);
            }
        }
    }


    public void set_speeds(bool flag)
    {
        double dspd = MWPlanner.conf.nav_speed;
        int cnt = 0;
        if(speeddialog.get_speed(out dspd) == true)
        {
            foreach (var t in get_selected_refs())
            {
                Gtk.TreeIter iter;
                GLib.Value cell;
                var path = t.get_path ();
                list_model.get_iter (out iter, path);
                list_model.get_value (iter, WY_Columns.ACTION, out cell);
                var act = (MSP.Action)cell;
                if (act == MSP.Action.RTH ||
                    act == MSP.Action.JUMP ||
                    act == MSP.Action.SET_POI ||
                    act == MSP.Action.SET_HEAD)
                    continue;
                if(flag == false)
                {
                    list_model.get_value (iter, WY_Columns.INT1, out cell);
                    if ((double)cell != 0)
                        continue;
                }
                list_model.set_value (iter, WY_Columns.INT1, dspd);
                cnt++;
            }
        }
        if(cnt != 0)
        {
            calc_mission();
        }
    }

    public void set_selection(Gtk.TreeIter iter)
    {
        var treesel = view.get_selection ();
        treesel.unselect_all();
        treesel.select_iter(iter);
    }

    public void clear_mission()
    {

        lastid=0;
        mp.markers.remove_all();
        purge = true;
        list_model.clear();
        purge = false;
        calc_mission();
    }

    public void calc_mission(double extra=0)
    {
        string route;

        int n_rows = list_model.iter_n_children(null) + 1;
        if (n_rows > 0)
        {
            double d;
            int lt;
            int et;

            var res = calc_mission_dist(out d, out lt, out et, extra, 0);
            if (res == true)
            {
                route = "Distance: %.0f%s, fly: %ds, loiter: %ds".printf(
                    Units.distance(d),
                    Units.distance_units(),
                    et,lt);
            }
            else
                route = "Indeterminate distance";
        }
        else
        {
            route = "Empty mission";
        }
        mp.stslabel.set_text(route);
    }

    public bool calc_mission_dist(out double d, out int lt, out int et,double extra=0.0, double speed = 0.0)
    {
        Gtk.TreeIter iter;
        MissionItem[] arry = {};
        double ets = 0.0;
        et = 0;

        if(speed == 0.0)
            speed = MWPlanner.conf.nav_speed;

        for(bool next=list_model.get_iter_first(out iter);next;next=list_model.iter_next(ref iter))
        {
            GLib.Value cell;

            list_model.set_value (iter, WY_Columns.TIP, (string)null);
            list_model.get_value (iter, WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            if (typ == MSP.Action.RTH)
                break;
            if(typ != MSP.Action.UNASSIGNED && typ != MSP.Action.SET_POI
               && typ != MSP.Action.SET_HEAD)
            {
                var m = MissionItem();
                m.action = typ;
                list_model.get_value (iter, WY_Columns.IDX, out cell);
                m.no = int.parse((string)cell);
                list_model.get_value (iter, WY_Columns.LAT, out cell);
                m.lat = (double)cell;
                list_model.get_value (iter, WY_Columns.LON, out cell);
                m.lon = (double)cell;
                list_model.get_value (iter, WY_Columns.INT1, out cell);
                if(typ == MSP.Action.WAYPOINT)
                    m.param1 = (int) (SPEED_CONV*(double)cell);
                else
                    m.param1 = (int)((double)cell);
                arry += m;
            }
            if (typ == MSP.Action.POSHOLD_UNLIM || typ == MSP.Action.LAND)
                break;
        }
        var n = 0;
        var rpt = 0;
        double lx = 0.0,ly=0.0;
        double lspd = speed;
        var lastn = 0;
        bool ready = false;
        d = 0.0;
        lt = 0;

        var nsize = arry.length;

        if (nsize > 0)
        {
            do
            {
                var typ = arry[n].action;
                var p1 = arry[n].param1;
                if(typ == MSP.Action.JUMP && arry[n].param2 == -1)
                {
                    d = 0.0;
                    lt = 0;
                    return false;
                }
                var cy = arry[n].lat;
                var cx = arry[n].lon;

                if (ready == true)
                {
                    double dx,cse;
                    if(typ == MSP.Action.JUMP)
                    {
                        var r = arry[n].param2;
                        rpt += 1;
                        if (rpt > r)
                            n += 1;
                        else
                            n = arry[n].param1-1;
                       continue;
                    }
                    Geo.csedist(ly,lx,cy,cx, out dx, out cse);

                    double ltim = (1852.0*dx) / lspd;
                    ets += ltim;

                    Value cell;
                    Gtk.TreeIter xiter;
                    var path = new Gtk.TreePath.from_indices (arry[lastn].no - 1);
                    list_model.get_iter(out xiter, path);

                    list_model.get_value (xiter, WY_Columns.TIP, out cell);
                    if((string)cell == null)
                    {
                        string hint; // CVT
                        hint = "Dist %.1f%s, to WP %d => %.1f%s, %.0f° %.0fs".printf(
                            Units.distance(d*1852),
                            Units.distance_units(),
                            arry[n].no,
                            Units.distance(dx*1852.0),
                            Units.distance_units(),
                            cse, ltim);
                        list_model.set_value (xiter, WY_Columns.TIP, hint);
                    }

                    d += dx;
                    lastn = n;
                    if (typ == MSP.Action.POSHOLD_TIME)
                    {
                        lt += arry[n].param1;
                    }

                    if (typ == MSP.Action.POSHOLD_UNLIM)
                    {
                        break;
                    }
                    else
                    {
                        n += 1;
                    }
                }
                else
                {
                    ready = true;
                    n += 1;
                }
                lx = cx;
                ly = cy;
                lspd = (p1 == 0) ? speed : ((double)p1)/SPEED_CONV;
            } while (n < nsize);
        }
        if(extra != 0)
        {
            d+=extra;
            ets += (extra*1852/ speed);
        }
        d *= 1852.0;
        et = (int)ets + 3 * nsize; // 3 * vertices to allow for slow down
        return true;
    }
}
