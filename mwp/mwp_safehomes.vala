/*
 * Copyright (C) 2018 Jonathan Hudson <jh+mwptools@daria.co.uk>
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

using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public enum SAFEHOMES {
    maxhomes = 8
}

public class SafeHomeMarkers : GLib.Object
{
    private Champlain.MarkerLayer safelayer;
    private Champlain.Label []safept;
    private bool []onscreen;
    public signal void safe_move(int idx, double lat, double lon);
    private Clutter.Color c_enabled;
    private Clutter.Color c_disabled;
    private Clutter.Color white;
    public signal void safept_move(int idx, double lat, double lon);
    public signal void safept_need_menu(int idx);

    public SafeHomeMarkers(Champlain.View view)
    {
        c_enabled.init(0xfb, 0xea, 0x04, 0xc8);
        c_disabled.init(0xfb, 0xea, 0x04, 0x68);
        white.init(0xff,0xff,0xff, 0xff);
        onscreen = new bool[SAFEHOMES.maxhomes];
        safept = new  Champlain.Label[SAFEHOMES.maxhomes];
        safelayer = new Champlain.MarkerLayer();
        view.add_layer (safelayer);
        for(var idx = 0; idx < SAFEHOMES.maxhomes; idx++)
        {
            safept[idx] = new Champlain.Label.with_text ("⏏#%d".printf(idx), "Sans 10",null,null);
            safept[idx].set_alignment (Pango.Alignment.RIGHT);
            safept[idx].set_color (c_disabled);
            safept[idx].set_text_color(white);
        }
    }

    public void show_safe_home(int idx, SafeHome h)
    {
        if(onscreen[idx] == false)
        {
            safept[idx].set_flags(ActorFlags.REACTIVE);
            safelayer.add_marker(safept[idx]);
            safept[idx].drag_motion.connect((dx,dy,evt) => {
                    safept_move(idx, safept[idx].get_latitude(), safept[idx].get_longitude());
                });
            safept[idx].button_press_event.connect((e) => {
                    if(e.button == 3)
                    {
                        if (safept[idx].draggable)
                            safept_need_menu(idx);
                    }
                    return false;
                });

            onscreen[idx] = true;
        }
        set_safe_colour(idx, h.enabled);
        safept[idx].set_location (h.lat, h.lon);
    }

    public void set_interactive(bool state)
    {
        for(var i = 0; i < SAFEHOMES.maxhomes; i++)
        {
            safept[i].set_draggable(state);
//            safept[i].set_selectable(state);
        }
    }

    public void set_safe_colour(int idx, bool state)
    {
        if (state)
            safept[idx].set_color (c_enabled);
        else
            safept[idx].set_color (c_disabled);
    }

    public void hide_safe_home(int idx)
    {
        if (onscreen[idx])
            safelayer.remove_marker(safept[idx]);
        onscreen[idx] = false;
    }
}

public struct SafeHome
{
    bool enabled;
    double lat;
    double lon;
}

public class  SafeHomeDialog : Object
{
    private string filename;
    private Gtk.ListStore sh_liststore;
    private bool visible = false;
    private Champlain.View view;
    private int pop_idx = -1;
    private Gtk.Switch switcher;
    private Gtk.Dialog dialog;
    private GLib.SimpleAction aq_fcl;
    private GLib.SimpleAction aq_fcs;

    public signal void request_safehomes(uint8 first, uint8 last);
    public signal void notify_publish_request();

    enum Column {
        ID,
        STATUS,
        LAT,
        LON,
        NO_COLS
    }

    private SafeHome []homes;
    private SafeHomeMarkers shmarkers;

    public SafeHomeDialog(Gtk.Window _w)
    {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <interface>
        <menu id="app-menu">
        <section>
        <item>
        <attribute name="label">Load safehome file</attribute>
        <attribute name="action">dialog.load</attribute>
        </item>
        <item>
        <attribute name="label">Save safehome file</attribute>
        <attribute name="action">dialog.save</attribute>
        </item>
        </section>
        <section>
        <item>
        <attribute name="label">Load from FC</attribute>
        <attribute name="action">dialog.loadfc</attribute>
        </item>
        <item>
        <attribute name="label">Save to FC</attribute>
        <attribute name="action">dialog.savefc</attribute>
        </item>
        </section>
        </menu>
        </interface>
        """;


        homes = new SafeHome[SAFEHOMES.maxhomes];
        filename = "None";

        dialog = new Gtk.Dialog.with_buttons("Safehomes", _w,
                                             DialogFlags.DESTROY_WITH_PARENT|
                                             DialogFlags.USE_HEADER_BAR);
        dialog.set_transient_for(_w);

        var fsmenu_button = new Gtk.MenuButton();
        Gtk.Image img = new Gtk.Image.from_icon_name("open-menu-symbolic",
                                                     Gtk.IconSize.BUTTON);
        var childs = fsmenu_button.get_children();
        fsmenu_button.remove(childs.nth_data(0));
        fsmenu_button.add(img);

        var tbox = dialog.get_header_bar();
        tbox.pack_start (fsmenu_button);

        switcher =  new Gtk.Switch();
        switcher.notify["active"].connect (() => {
                var state = switcher.get_active();
                display_homes(state);
            });

        dialog.response.connect((v) => {
                visible = false;
                shmarkers.set_interactive(false);
                dialog.hide();
            });

        tbox.pack_end (switcher);
        tbox.pack_end (new Gtk.Label("Display on map"));

        var sbuilder = new Gtk.Builder.from_string(xml, -1);
        var menu = sbuilder.get_object("app-menu") as GLib.MenuModel;
        var pop = new Gtk.Popover.from_model(fsmenu_button, menu);
        fsmenu_button.set_popover(pop);
        fsmenu_button.set_use_popover(false);

        var dg = new GLib.SimpleActionGroup();

        var aq = new GLib.SimpleAction("load",null);
        aq.activate.connect(() => {
                run_chooser( Gtk.FileChooserAction.OPEN, _w);
            });
        dg.add_action(aq);

        aq = new GLib.SimpleAction("save",null);
        aq.activate.connect(() => {
                run_chooser( Gtk.FileChooserAction.SAVE, _w);
            });
        dg.add_action(aq);

        aq_fcl = new GLib.SimpleAction("loadfc",null);
        aq_fcl.activate.connect(() => {
                request_safehomes(0, 7);
            });
        aq_fcl.set_enabled(false);
        dg.add_action(aq_fcl);

        aq_fcs = new GLib.SimpleAction("savefc",null);
        aq_fcs.activate.connect(() => {
                notify_publish_request();
            });
        aq_fcs.set_enabled(false);
        dg.add_action(aq_fcs);

        dialog.insert_action_group("dialog", dg);

        dialog.delete_event.connect (() => {
                dialog.hide();
                visible = false;
                shmarkers.set_interactive(false);
                return true;
            });

        var tview = new Gtk.TreeView ();
        tview.button_press_event.connect( (event) => {
                if(event.button == 3)
                {
                    var sel = tview.get_selection ();
                    if(sel.count_selected_rows () == 1)
                    {
                        var rows = sel.get_selected_rows(null);
                        Gtk.TreeIter iter;
                        sh_liststore.get_iter (out iter, rows.nth_data(0));
                        row_menu(event, iter);
                    }
                    return true;
                }
                return false;
            });

        sh_liststore = new Gtk.ListStore (Column.NO_COLS,
                                          typeof (int),
                                          typeof (bool),
                                          typeof (double),
                                          typeof (double) );

        tview.set_model (sh_liststore);
        tview.insert_column_with_attributes (-1, "Id",
                                            new Gtk.CellRendererText (), "text",
                                            Column.ID);

        var cell = new Gtk.CellRendererToggle();
        tview.insert_column_with_attributes (-1, "Enabled",
                                             cell, "active", Column.STATUS);
        cell.toggled.connect((p) => {
                Gtk.TreeIter iter;
                int idx = 0;
                sh_liststore.get_iter(out iter, new TreePath.from_string(p));
                sh_liststore.get (iter, Column.ID, &idx);
                homes[idx].enabled = !homes[idx].enabled;
                sh_liststore.set (iter, Column.STATUS, homes[idx].enabled);
                if(homes[idx].enabled)
                {
                    if (homes[idx].lat == 0 && homes[idx].lon == 0)
                    {
                        set_default_loc(idx);
                        sh_liststore.set (iter,
                                          Column.LAT, homes[idx].lat,
                                          Column.LON, homes[idx].lon);
                    }
                    shmarkers.show_safe_home(idx, homes[idx]);
                }
                else
                {
                    shmarkers.set_safe_colour(idx, false);
                }
            });

        var lacell = new Gtk.CellRendererText ();

        tview.insert_column_with_attributes (-1, "Latitude",
                                             lacell,
                                             "text", Column.LAT);

        var col =  tview.get_column(Column.LAT);
        col.set_cell_data_func(lacell, (col,_cell,model,iter) => {
                GLib.Value v;
                model.get_value(iter, Column.LAT, out v);
                double val = (double)v;
                string s = PosFormat.lat(val,MWP.conf.dms);
                _cell.set_property("text",s);
            });

        var locell = new Gtk.CellRendererText ();

        tview.insert_column_with_attributes (-1, "Longitude",
                                             locell,
                                            "text", Column.LON);
        col =  tview.get_column(Column.LON);
        col.set_cell_data_func(locell, (col,_cell,model,iter) => {
                GLib.Value v;
                model.get_value(iter, Column.LON, out v);
                double val = (double)v;
                string s = PosFormat.lon(val,MWP.conf.dms);
                _cell.set_property("text",s);
            });

        var box = dialog.get_content_area();
        box.pack_start (tview, false, false, 0);

        tbox.set_decoration_layout(":close");
        tbox.set_show_close_button(true);

        Gtk.TreeIter iter;
        for(var i = 0; i < SAFEHOMES.maxhomes; i++)
        {
            sh_liststore.append (out iter);
            sh_liststore.set (iter,
                              Column.ID, i,
                              Column.STATUS, false,
                              Column.LAT, 0.0,
                              Column.LON, 0.0);
        }
    }

    public void online_change(uint32 v)
    {
        var sens = (v >= MWP.FCVERS.hasSAFEAPI); //.0x020700
        aq_fcs.set_enabled(sens);
        aq_fcl.set_enabled(sens);
    }

    public SafeHome get_home(uint8 idx)
    {
        return homes[idx];
    }

    private void row_menu(Gdk.EventButton e, Gtk.TreeIter iter)
    {
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
        /*
    private void set_menu_state(string action, bool state)
    {
        var ac = window.lookup_action(action) as SimpleAction;
        ac.set_enabled(state);
    }
        */
    public void receive_safehome(uint8 idx, SafeHome shm)
    {
        refresh_home(idx,  shm.enabled, shm.lat, shm.lon);
    }

    private void clear_item(int idx, Gtk.TreeIter iter)
    {
        homes[idx].enabled = false;
        homes[idx].lat = 0;
        homes[idx].lon = 0;
        sh_liststore.set (iter,
                          Column.STATUS, homes[idx].enabled,
                          Column.LAT, homes[idx].lat,
                          Column.LON, homes[idx].lon);
        shmarkers.hide_safe_home(idx);
    }

    public void set_view(Champlain.View v)
    {
        view = v;
        shmarkers = new SafeHomeMarkers(v);
        shmarkers.safept_move.connect((idx,la,lo) => {
            homes[idx].lat = la;
            homes[idx].lon = lo;
            Gtk.TreeIter iter;
            if(sh_liststore.iter_nth_child (out iter, null, idx))
                sh_liststore.set (iter,
                                  Column.LAT, homes[idx].lat,
                                  Column.LON, homes[idx].lon);
            });
        shmarkers.safept_need_menu.connect((idx) => {
                pop_idx = idx;
            });
    }

    public void pop_menu(Gdk.EventButton e)
    {
        if(pop_idx != -1)
        {
            var idx = pop_idx;
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
        }
        pop_idx = -1;
    }


    private void set_default_loc(int idx)
    {
        homes[idx].lat = view.get_center_latitude();
        homes[idx].lon = view.get_center_longitude();
    }

    private void read_file()
    {
        FileStream fs = FileStream.open (filename, "r");
        if(fs == null)
        {
            return;
        }
        string s;

        while((s = fs.read_line()) != null)
        {
            if(s.has_prefix("safehome "))
            {
                var parts = s.split_set(" ");
                    if(parts.length == 5)
                    {
                        var idx = int.parse(parts[1]);
                        if (idx >= 0 && idx < SAFEHOMES.maxhomes)
                        {
                            var ena = (parts[2] == "1") ? true : false;
                            var lat = double.parse(parts[3]) /10000000.0;
                            var lon = double.parse(parts[4]) /10000000.0;
                            refresh_home(idx, ena, lat, lon);
                        }
                    }
            }
        }
    }

    private void refresh_home(int idx, bool ena, double lat, double lon)
    {
        homes[idx].enabled = ena;
        homes[idx].lat = lat;
        homes[idx].lon = lon;
        Gtk.TreeIter iter;
        if(sh_liststore.iter_nth_child (out iter, null, idx))
            sh_liststore.set (iter,
                              Column.STATUS, homes[idx].enabled,
                              Column.LAT, homes[idx].lat,
                              Column.LON, homes[idx].lon);
        if(switcher.active)
        {
            if(homes[idx].lat != 0 && homes[idx].lon != 0)
                shmarkers.show_safe_home(idx, homes[idx]);
            else
                shmarkers.hide_safe_home(idx);
        }
    }

    private void display_homes(bool state)
    {
        for (var idx = 0; idx < SAFEHOMES.maxhomes; idx++)
        {
            if(state)
            {
                if(homes[idx].lat != 0 && homes[idx].lon != 0)
                {
                    shmarkers.show_safe_home(idx, homes[idx]);
                }
            }
            else
                shmarkers.hide_safe_home(idx);
        }
    }

    public void load_homes(string fn, bool disp)
    {
        filename = fn;
        read_file();
        if (disp)
        {
            display_homes(true);
            switcher.set_active(true);
        }
    }

    private void write_out(FileStream fs)
    {
        var idx = 0;
        foreach (var h in homes)
        {
            var ena = (h.enabled) ? 1 : 0;
            fs.printf("safehome %d %d %d %d\n", idx, ena,
                      (int)(h.lat*10000000), (int)(h.lon*10000000));
            idx++;
        }
    }

    private void save_file()
    {
        if(FileUtils.test(filename, FileTest.EXISTS))
        {
            string []lines = {};
            string s;
            bool written = false;

            FileStream fs = FileStream.open (filename, "r");
            while((s = fs.read_line()) != null)
                lines += s;

            fs = FileStream.open (filename, "w");
            foreach (var l in lines)
            {
                if(l.has_prefix("safehome "))
                {
                    if (written == false)
                    {
                        write_out(fs);
                        written = true;
                    }
                }
                else
                {
                    fs.puts(l);
                    fs.puts("\n");
                }
            }
            if (written == false)
                write_out(fs);
        } else {
            FileStream fs = FileStream.open (filename, "w");
            fs.puts("# safehome\n");
            write_out(fs);
        }
    }
//current_folder_changed ()
    private void run_chooser(Gtk.FileChooserAction action, Gtk.Window window)
    {
        Gtk.FileChooserDialog fc = new Gtk.FileChooserDialog (
            "Safehome definition",
            window, action,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            (action == Gtk.FileChooserAction.SAVE) ? "_Save" : "_Open",
            Gtk.ResponseType.ACCEPT);

        fc.set_modal(true);
        fc.select_multiple = false;

        if(action == Gtk.FileChooserAction.SAVE && filename != null)
            fc.set_filename(filename);

        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Text files");
        filter.add_pattern ("*.txt");
        fc.add_filter (filter);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        fc.add_filter (filter);

        fc.response.connect((result) => {
                if (result== Gtk.ResponseType.ACCEPT) {
                    filename  = fc.get_file().get_path ();
                    if (action == Gtk.FileChooserAction.OPEN) {
                        load_homes(filename, switcher.active);
                    }
                    else if (result == Gtk.ResponseType.ACCEPT)
                    {
                        save_file();
                    }
                }
                fc.close();
                fc.destroy();
            });
        fc.show();
    }

    public void show(Gtk.Window w)
    {
        if(!visible)
        {
            visible = true;
            dialog.show_all ();
            shmarkers.set_interactive(true);
        }
    }
}
