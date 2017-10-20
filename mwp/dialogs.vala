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


extern int speech_init(string voice);
extern void speech_say(string text);
//extern void speech_terminate();

public class Units :  GLib.Object
{
    private const string [] dnames = {"m", "ft", "yd","mfg"};
    private const string [] dspeeds = {"m/s", "kph", "mph", "kts", "mfg/µftn"};
    private const string [] dfix = {"no fix","","2d","3d"};

    public static double distance (double d)
    {
        switch(MWPlanner.conf.p_distance)
        {
            case 1:
                d *= 3.2808399;
                break;
            case 2:
                d *= 1.0936133;
                break;
            case 3: // millifurlongs
                d *= 0.0049709695;
                break;
        }
        return d;
    }
    public static double speed (double d)
    {
        switch(MWPlanner.conf.p_speed)
        {
            case 1:
                d *= 3.6;
                break;
            case 2:
                d *= 2.2369363;
                break;
            case 3:
                d *= 1.9438445;
                break;
            case 4: // milli-furlongs / micro-fortnight
                d *= (6012.8848/1000.0);
                break;
        }
        return d;
    }

    public static double va_speed (double d)
    {
        if (MWPlanner.conf.p_speed > 1)
                d *= 3.2808399; // ft/sec
        return d;
    }

    public static string distance_units()
    {
        return dnames[MWPlanner.conf.p_distance];
    }

    public static string speed_units()
    {
        return dspeeds[MWPlanner.conf.p_speed];
    }

    public static string va_speed_units()
    {
        return (MWPlanner.conf.p_speed > 1) ? "ft/s" : "m/s";
    }

    public static string fix(uint8 fix)
    {
        return dfix[fix];
    }
}


public class OdoView : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Label odospeed;
    private Gtk.Label ododist;
    private Gtk.Label odotime;
    private Gtk.Label odospeed_u;
    private Gtk.Label ododist_u;
    private Gtk.Button odoclose;
    private uint to = 15;
    private uint tid = 0;
    private bool visible = false;
    private Gtk.Window parent = null;

    public OdoView(Gtk.Builder builder, Gtk.Window? w, uint _to)
    {
        parent = w;
        dialog = builder.get_object ("odoview") as Gtk.Dialog;
        ododist = builder.get_object ("ododist") as Gtk.Label;
        odospeed = builder.get_object ("odospeed") as Gtk.Label;
        ododist_u = builder.get_object ("ododist_u") as Gtk.Label;
        odospeed_u = builder.get_object ("odospeed_u") as Gtk.Label;
        odotime = builder.get_object ("odotime") as Gtk.Label;
        odoclose = builder.get_object ("odoclose") as Gtk.Button;

        to = _to;

        dialog.delete_event.connect (() => {
                dismiss();
                return true;
            });

        odoclose.clicked.connect (() => {
                dismiss();
            });
    }

    public void display(Odostats o, bool autohide=false)
    {
        ododist.label = "  %.0f ".printf(Units.distance(o.distance));
        odospeed.label = "  %.1f ".printf(Units.speed(o.speed));
        odotime.label = " %u:%02u ".printf(o.time / 60, o.time % 60);
        ododist_u.label = Units.distance_units();
        odospeed_u.label =  Units.speed_units();
        unhide();
        if(autohide)
        {
            if(to > 0)
            {
                tid = Timeout.add_seconds(to, () => {
                        tid=0;
                        dismiss();
                        return Source.REMOVE;
                    });
            }
        }
    }

    public void unhide()
    {
        visible = true;
        dialog.set_transient_for(parent);
        dialog.show_all();
    }

    public void dismiss()
    {
        if(tid != 0)
            Source.remove(tid);
        tid = 0;
        visible=false;
        dialog.hide();
    }
}

public class ArtWin : GLib.Object
{
    public Gtk.Box  box {get; private set;}
    private Ath.Horizon ath;
    private bool inv = false;

    public ArtWin(bool _inv = false)
    {
        box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        ath = new Ath.Horizon();
        box.pack_start(ath, true,true,0);
        int sz = MWPlanner.conf.ahsize;
        inv = _inv;
        box.set_size_request (sz, sz);
        box.show_all();
    }

    public void update(short sx, short sy, bool visible)
    {
        if(visible)
        {
            double dx,dy;
            dx = sx/10.0;
            if(inv == false)
                dx = -dx;

            if (dx < 0)
                dx += 360;

            dy = -sy/10.0;
                // roll, pitch
            ath.update(dx,dy);
        }
    }
}

public class TelemetryStats : GLib.Object
{
    private Gtk.Label elapsed;
    private Gtk.Label rxbytes;
    private Gtk.Label txbytes;
    private Gtk.Label rxrate;
    private Gtk.Label txrate;
    private Gtk.Label timeouts;
    private Gtk.Label waittime;
    private Gtk.Label cycletime;
    private Gtk.Label messages;
    public Gtk.Grid grid {get; private set;}

    public TelemetryStats(Gtk.Builder builder)
    {
        grid = builder.get_object ("ss_grid") as Gtk.Grid;
        elapsed = builder.get_object ("ss-elapsed") as Gtk.Label;
        rxbytes = builder.get_object ("ss-rxbytes") as Gtk.Label;
        txbytes = builder.get_object ("ss-txbytes") as Gtk.Label;
        rxrate = builder.get_object ("ss-rxrate") as Gtk.Label;
        txrate = builder.get_object ("ss-txrate") as Gtk.Label;
        timeouts = builder.get_object ("ss-timeout") as Gtk.Label;
        waittime = builder.get_object ("ss-wait") as Gtk.Label;
        cycletime = builder.get_object ("ss-cycle") as Gtk.Label;
        messages = builder.get_object ("ss-msgs") as Gtk.Label;
        grid.show_all();
    }


   public void annul()
   {
       elapsed.set_label("---");
       rxbytes.set_label("---");
       txbytes.set_label("---");
       rxrate.set_label("---");
       txrate.set_label("---");
       timeouts.set_label("---");
       waittime.set_label("---");
       cycletime.set_label("---");
       messages.set_label("---");
   }

   public void update(TelemStats t, bool visible)
    {
        if(visible)
        {
            elapsed.set_label("%.0f s".printf(t.s.elapsed));
            rxbytes.set_label("%lu b".printf(t.s.rxbytes));
            txbytes.set_label("%lu b".printf(t.s.txbytes));
            rxrate.set_label("%.0f b/s".printf(t.s.rxrate));
            txrate.set_label("%.0f b/s".printf(t.s.txrate));
            timeouts.set_label(t.toc.to_string());
            waittime.set_label("%d ms".printf(t.tot));
            cycletime.set_label("%lu ms".printf(t.avg));
            messages.set_label(t.s.msgs.to_string());
        }
    }
}

public class FlightBox : GLib.Object
{
    private Gtk.Label big_lat;
    private Gtk.Label big_lon;
    private Gtk.Label big_rng;
    private Gtk.Label big_bearing;
    private Gtk.Label big_hdr;
    private Gtk.Label big_alt;
    private Gtk.Label big_spd;
    private Gtk.Label big_sats;
    public Gtk.Box vbox {get; private set;}
    private bool _allow_resize = true;
    private Gtk.Grid grid;
    private Gtk.Window _w;
    public static uint fh1=20;

    public void allow_resize(bool exp)
    {
        grid.expand = _allow_resize = exp;
    }

    public FlightBox(Gtk.Builder builder, Gtk.Window pw)
    {
        _w = pw;
        vbox  = builder.get_object ("flight_box") as Gtk.Box;
        grid = builder.get_object ("fv_grid") as Gtk.Grid;
        grid.set_column_homogeneous (true);
        big_lat = builder.get_object ("big_lat") as Gtk.Label;
        big_lon = builder.get_object ("big_lon") as Gtk.Label;
        big_rng = builder.get_object ("big_rng") as Gtk.Label;
        big_bearing = builder.get_object ("big_bearing") as Gtk.Label;
        big_hdr = builder.get_object ("big_hdr") as Gtk.Label;
        big_alt = builder.get_object ("big_alt") as Gtk.Label;
        big_spd = builder.get_object ("big_spd") as Gtk.Label;
        big_sats = builder.get_object ("big_sats") as Gtk.Label;
        vbox.size_allocate.connect((a) => {
                if(_allow_resize)
                {
                    fh1 = a.width*MWPlanner.conf.fontfact/100;
                    Idle.add(() => {update(true);
                                    return false;});
                }
            });
        vbox.show_all();
    }

   public void annul()
   {
       update(true);
   }

   public void update(bool visible)
   {
       if(visible)
       {
           var fh2 = (MWPlanner.conf.dms) ? fh1*45/100 : fh1/2;
           if(fh1 > 96)
               fh1 = 96;

           var fh3 = fh1;
           double falt = (double)NavStatus.alti.estalt/100.0;
           if(falt < 0.0 || falt > 20.0)
               falt = Math.round(falt);

           if(falt > 9999.0 || falt < -999.0)
               fh3 = fh3 * 60/100;
           else if(falt > 999.0 || falt < -99.0)
               fh3 = fh3 * 75 /100;

           var s=PosFormat.lat(GPSInfo.lat,MWPlanner.conf.dms);
           big_lat.set_label("<span font='%u'>%s</span>".printf(fh2,s));
           s=PosFormat.lon(GPSInfo.lon,MWPlanner.conf.dms);
           big_lon.set_label("<span font='%u'>%s</span>".printf(fh2,s));
           var brg = NavStatus.cg.direction;
           if(brg < 0)
               brg += 360;
           if(NavStatus.recip)
               brg = ((brg + 180) % 360);
           big_rng.set_label(
               "Range <span font='%u'>%.0f</span>%s".printf(
                   fh1,
                   Units.distance(NavStatus.cg.range),
                   Units.distance_units()
                                                            ));
           big_bearing.set_label("Bearing <span font='%u'>%d°</span>".printf(fh1,brg));
           big_hdr.set_label("Heading <span font='%u'>%d°</span>".printf(fh3,NavStatus.hdr));
           big_alt.set_label(
               "Alt <span font='%u'>%.1f</span>%s".printf(
                   fh3,
                   Units.distance(falt),
                   Units.distance_units() ));

           var fhsp = fh1;
           if(GPSInfo.spd >= 100)
               fhsp = fh1*75/100;

           big_spd.set_label(
               "Speed <span font='%u'>%.1f</span>%s".printf(
                   fhsp,
                   Units.speed(GPSInfo.spd),
                   Units.speed_units() ) );
           string hdoptxt="";
           if(GPSInfo.hdop != -1.0 && GPSInfo.hdop < 100.0)
           {
               string htxt;
               if(GPSInfo.hdop > 9.95)
                   htxt = "%.0f".printf(GPSInfo.hdop);
               else
                   htxt = "%.1f".printf(GPSInfo.hdop);
                hdoptxt = " / <span font='%u'>%s</span>".printf(fh2,htxt);
           }
           var slabel = "Sats <span font='%u'>%d</span> %s%s".printf(
               fh1, GPSInfo.nsat,Units.fix(GPSInfo.fix), hdoptxt);
           big_sats.set_label(slabel);
       }
   }
}

public class MapSeeder : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.SpinButton tile_minzoom;
    private Gtk.SpinButton tile_maxzoom;
    private Gtk.SpinButton tile_age;
    private Gtk.Label tile_stats;
    private Gtk.Button apply;
    private Gtk.Button stop;
    private int age  {get; set; default = 30;}
    private TileUtil ts;

    public MapSeeder(Gtk.Builder builder, Gtk.Window? w)
    {
        dialog = builder.get_object ("seeder_dialog") as Gtk.Dialog;
        dialog.set_transient_for(w);
        tile_minzoom = builder.get_object ("tile_minzoom") as Gtk.SpinButton;
        tile_maxzoom = builder.get_object ("tile_maxzoom") as Gtk.SpinButton;
        tile_age = builder.get_object ("tile_age") as Gtk.SpinButton;
        tile_stats = builder.get_object ("tile_stats") as Gtk.Label;
        apply = builder.get_object ("tile_start") as Gtk.Button;
        stop = builder.get_object ("tile_stop") as Gtk.Button;

        dialog.delete_event.connect (() => {
                reset();
                return true;
            });

        ts = new TileUtil();
        tile_minzoom.adjustment.value_changed.connect (() =>  {
                int minv = (int)tile_minzoom.adjustment.value;
                int maxv = (int)tile_maxzoom.adjustment.value;
                if (minv > maxv)
                {
                    tile_minzoom.adjustment.value = maxv;
                }
                else
                {
                    ts.set_zooms(minv,maxv);
                    var nt = ts.build_table();
                    set_label(nt);
                }
            });
        tile_maxzoom.adjustment.value_changed.connect (() => {
                int minv = (int)tile_minzoom.adjustment.value;
                int maxv = (int)tile_maxzoom.adjustment.value;
                if (maxv < minv )
                {
                    tile_maxzoom.adjustment.value = minv;
                }
                else
                {
                    ts.set_zooms(minv,maxv);
                    var nt = ts.build_table( );
                    set_label(nt);
                }
            });

        apply.clicked.connect(() => {
                apply.sensitive = false;
                int days = (int)tile_age.adjustment.value;
                ts.set_delta(days);
                stop.set_label("Stop");
                ts.start_seeding();
            });

        stop.clicked.connect(() => {
                reset();
            });
    }

    private void reset()
    {
        dialog.hide();
        ts.stop();
        ts = null;
    }


    private void set_label(TileUtil.TileStats s)
    {
        var lbl = "Tiles: %u / Skip: %u / DL: %u / Err: %u".printf(s.nt, s.skip, s.dlok, s.dlerr);
        tile_stats.set_label(lbl);

            // need to force dialog update
        while(Gtk.events_pending())
            Gtk.main_iteration();

        MWPLog.message("%s\n", lbl);
    }

    public void run_seeder(string mapid, int zval, Champlain.BoundingBox bbox)
    {
        var map_source_factory = Champlain.MapSourceFactory.dup_default();
        var sources =  map_source_factory.get_registered();
        string uri = null;
        int minz = 0;
        int maxz = 19;

        if(ts == null)
            ts = new TileUtil();

        foreach (Champlain.MapSourceDesc sr in sources)
        {
            if(mapid == sr.get_id())
            {
                uri = sr.get_uri_format ();
                minz = (int)sr.get_min_zoom_level();
                maxz = (int)sr.get_max_zoom_level();
                break;
            }
        }
        if(uri != null)
        {
            stop.set_label("Close");
            apply.sensitive = true;
            tile_maxzoom.adjustment.lower = minz;
            tile_maxzoom.adjustment.upper = maxz;
            tile_maxzoom.adjustment.value = zval;

            tile_minzoom.adjustment.lower = minz;
            tile_minzoom.adjustment.upper = maxz;
            tile_minzoom.adjustment.value = zval-4;
            tile_age.adjustment.value = age;

            ts.show_stats.connect((stats) => {
                    set_label(stats);
                });
            ts.tile_done.connect(() => {
                    apply.sensitive = true;
                    stop.set_label("Close");
                });
            ts.set_range(bbox.bottom, bbox.left, bbox.top, bbox.right);
            ts.set_misc(mapid, uri);
            ts.set_zooms(zval-4, zval);
            var nt = ts.build_table();
            set_label(nt);
            dialog.show_all();
        }
    }
}

public class MapSourceDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Label map_name;
    private Gtk.Label map_id;
    private Gtk.Label map_minzoom;
    private Gtk.Label map_maxzoom;
    private Gtk.Label map_uri;

    public MapSourceDialog(Gtk.Builder builder, Gtk.Window? w=null)
    {
        dialog = builder.get_object ("map_source_dialog") as Gtk.Dialog;
        dialog.set_transient_for(w);
        map_name = builder.get_object ("map_name") as Gtk.Label;
        map_id = builder.get_object ("map_id") as Gtk.Label;
        map_uri = builder.get_object ("map_uri") as Gtk.Label;
        map_minzoom = builder.get_object ("map_minzoom") as Gtk.Label;
        map_maxzoom = builder.get_object ("map_maxzoom") as Gtk.Label;
    }

    public void show_source(string name, string id, string uri, uint minzoom, uint maxzoom)
    {
        map_name.set_label(name);
        map_id.set_label(id);
        map_uri.set_label(uri);
        map_minzoom.set_label(minzoom.to_string());
        map_maxzoom.set_label(maxzoom.to_string());
        dialog.show_all();
        dialog.run();
        dialog.hide();
    }
}

public class SpeedDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry spd_entry;

    public SpeedDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("speeddialog") as Gtk.Dialog;
        spd_entry = builder.get_object ("defspeedset") as Gtk.Entry;
    }

    public bool get_speed(out double spd)
    {
        var res = false;
        dialog.show_all();
        spd = 0.0;
        var id = dialog.run();
        switch(id)
        {
            case 1001:
                spd  = InputParser.get_scaled_real(spd_entry.get_text(),"s");
                res = true;
                break;

            case 1002:
                break;
        }
        dialog.hide();
        return res;
    }
}

public class AltDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry alt_entry;

    public AltDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("altdialog") as Gtk.Dialog;
        alt_entry = builder.get_object ("defaltset") as Gtk.Entry;
    }

    public bool get_alt(out double alt)
    {
        var res = false;
        dialog.show_all();
        alt = 0.0;
        var id = dialog.run();
        switch(id)
        {
            case 1001:
                alt = InputParser.get_scaled_real(alt_entry.get_text(),"d");
                res = true;
                break;

            case 1002:
                break;
        }
        dialog.hide();
        return res;
    }
}

public class DeltaDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry dlt_entry1;
    private Gtk.Entry dlt_entry2;
    private Gtk.Entry dlt_entry3;

    public DeltaDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("delta-dialog") as Gtk.Dialog;
        dlt_entry1 = builder.get_object ("dlt_entry1") as Gtk.Entry;
        dlt_entry2 = builder.get_object ("dlt_entry2") as Gtk.Entry;
        dlt_entry3 = builder.get_object ("dlt_entry3") as Gtk.Entry;
    }

    public bool get_deltas(out double dlat, out double dlon, out int dalt)
    {
        var res = false;
        dialog.show_all();
        dlat = dlon = 0.0;
        dalt = 0;
        var id = dialog.run();
        switch(id)
        {
            case 1001:
                dlat = g_strtod(dlt_entry1.get_text(),null);
                dlon = g_strtod(dlt_entry2.get_text(),null);
                dalt = (int)InputParser.get_scaled_int(dlt_entry3.get_text());
                res = true;
                break;

            case 1002:
                break;
        }
        dialog.hide();
        return res;
    }

}

public class SetPosDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry lat_entry;
    private Gtk.Entry lon_entry;

    public SetPosDialog(Gtk.Builder builder,Gtk.Window? w=null)
    {
        dialog = builder.get_object ("gotodialog") as Gtk.Dialog;
        dialog.set_transient_for(w);
        lat_entry = builder.get_object ("golat") as Gtk.Entry;
        lon_entry = builder.get_object ("golon") as Gtk.Entry;
    }

    public bool get_position(out double glat, out double glon)
    {
        var res = false;
        dialog.show_all();
        glat = glon = 0.0;
        var id = dialog.run();
        switch(id)
        {
            case 1001:
                var t1 = lat_entry.get_text();
                var t2 = lon_entry.get_text();
                if (t2 == "")
                {
                    string []parts;
                    parts = t1.split (" ");
                    if(parts.length == 2)
                    {
                        t1 = parts[0];
                        t2 = parts[1];
                    }
                }
                glat = InputParser.get_latitude(t1);
                glon = InputParser.get_longitude(t2);
                res = true;
                break;

            case 1002:
                break;
        }
        dialog.hide();
        return res;
    }
}

public class SwitchDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    public SwitchDialog(Gtk.Builder builder, Gtk.Window? w=null)
    {
        dialog = builder.get_object ("switch-dialogue") as Gtk.Dialog;
        dialog.set_transient_for(w);
    }
    public void run()
    {
        dialog.show_all();
        var id = dialog.run();
        dialog.hide();
        if(id == 1002)
            Posix.exit(255);
    }
}


public class PrefsDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry[]ents = {};
    private Gtk.RadioButton[] buttons={};

    private uint pspeed;
    private uint pdist;
    private bool pdms;
    private Gtk.Switch rthland;

    private enum Buttons
    {
        DDD=0,
        DMS,

        METRE,
        FEET,
        YARDS,

        MSEC,
        KPH,
        MPH,
        KNOTS
    }

    private void toggled (Gtk.ToggleButton button) {
        if(button.get_active())
        {
            switch(button.label)
            {
                case "DDD.dddddd":
                    pdms = false;
                    break;
                case "DDD:MM:SS.s":
                    pdms = true;
                    break;
                case "Metres":
                    pdist = 0;
                    break;
                case "Feet":
                    pdist = 1;
                    break;
                case "Yards":
                    pdist = 2;
                    break;
                case "m/s":
                    pspeed = 0;
                    break;
                case "kph":
                    pspeed = 1;
                    break;
                case "mph":
                    pspeed = 2;
                    break;
                case "knots":
                    pspeed = 3;
                    break;
                default:
                    stderr.printf("Invalid label %s\n", button.label);
                    break;
            }
        }
    }

    public PrefsDialog(Gtk.Builder builder, Gtk.Window? w)
    {
        dialog = builder.get_object ("prefs-dialog") as Gtk.Dialog;
        for (int i = 1; i < 10; i++)
        {
            var id = "prefentry%d".printf(i);
            var e = builder.get_object (id) as Gtk.Entry;
            ents += e;
        }
        rthland = builder.get_object("prefswitch10") as Gtk.Switch;

        Gtk.RadioButton button;
        string [] pnames = {
            "uprefs-ddd", "uprefs-dms",
            "uprefs-metre", "uprefs-feet", "uprefs-yards",
            "uprefs-msec", "uprefs-kph", "uprefs-mph", "uprefs-knots"
        };

        foreach(var s in pnames)
        {
            button = builder.get_object (s) as Gtk.RadioButton;
            button.toggled.connect (toggled);
            buttons += button;
        }

        dialog.set_default_size (640, 320);
        dialog.set_transient_for(w);
        var content = dialog.get_content_area () as Gtk.Box;
        Gtk.Notebook notebook = new Gtk.Notebook ();
        content.pack_start (notebook, false, true, 0);
        content.spacing = 4;

        var gprefs = builder.get_object ("gprefs") as Gtk.Box;
        var uprefs = builder.get_object ("uprefs") as Gtk.Box;

        notebook.append_page(gprefs,new Gtk.Label("General"));
        notebook.append_page(uprefs,new Gtk.Label("Units"));
    }

    public int run_prefs(ref MWPSettings conf)
    {
        int id = 0;
        StringBuilder sb = new StringBuilder ();
        if(conf.devices != null)
        {
            var delimiter = ", ";
            foreach (string s in conf.devices)
            {
                sb.append(s);
                sb.append(delimiter);
            }
            sb.truncate (sb.len - delimiter.length);
            ents[0].set_text(sb.str);
        }

        rthland.active = conf.rth_autoland;

        string dp;
        dp = PosFormat.lat(conf.latitude, conf.dms);
        ents[1].set_text(dp);
        dp = PosFormat.lon(conf.longitude, conf.dms);
        ents[2].set_text(dp);
        ents[3].set_text("%u".printf(conf.loiter));

        var al = Units.distance((double)conf.altitude);
        ents[4].set_text("%.0f".printf(al));
        al = Units.speed(conf.nav_speed);
        ents[5].set_text("%.2f".printf(al));
        ents[6].set_text(conf.defmap);
        ents[7].set_text("%u".printf(conf.zoom));
        ents[8].set_text("%u".printf(conf.speakint));

        if(conf.dms)
            buttons[Buttons.DMS].set_active(true);
        else
            buttons[Buttons.DDD].set_active(true);

        buttons[conf.p_distance + Buttons.METRE].set_active(true);
        buttons[conf.p_speed + Buttons.MSEC].set_active(true);

        dialog.show_all ();
        id = dialog.run();
        switch(id)
        {
            case 1001:
                var str = ents[0].get_text();
                double d;
                uint u;
                if(sb.str != str)
                {
                    var strs = str.split(",");
                    for(int i=0; i<strs.length;i++)
                    {
                        strs[i] = strs[i].strip();
                    }
                    conf.settings.set_strv( "device-names", strs);

                }
                str = ents[1].get_text();
                d=InputParser.get_latitude(str);
                if(Math.fabs(conf.latitude - d) > 1e-5)
                {
                    conf.settings.set_double("default-latitude", d);
                }
                str = ents[2].get_text();
                d=InputParser.get_longitude(str);
                if(Math.fabs(conf.longitude - d) > 1e-5)
                if(conf.longitude != d)
                {
                    conf.settings.set_double("default-longitude", d);
                }
                str = ents[3].get_text();
                u=int.parse(str);
                if(conf.loiter != u)
                {
                    conf.settings.set_uint("default-loiter", u);
                }
                str = ents[4].get_text();
                u = (uint)InputParser.get_scaled_int(str);
                if(conf.altitude != u)
                {
                    conf.settings.set_uint("default-altitude", u);
                }
                str = ents[5].get_text();
                d = InputParser.get_scaled_real(str, "s");
                if(Math.fabs(conf.nav_speed -d) > 0.1)
                {
                    conf.settings.set_double("default-nav-speed", d);
                }
                str = ents[6].get_text();
                if(conf.defmap !=str)
                {
                    conf.settings.set_string ("default-map", str);
                }
                str = ents[7].get_text();
                u=int.parse(str);
                if(conf.zoom != u)
                {
                    conf.settings.set_uint("default-zoom", u);
                }

                if(conf.dms != pdms)
                {
                    conf.settings.set_boolean("display-dms", pdms);
                }

                if(conf.p_distance != pdist)
                {
                    conf.settings.set_uint("display-distance", pdist);
                }

                if(conf.p_speed != pspeed)
                {
                    conf.settings.set_uint("display-speed", pspeed);
                }

                str = ents[8].get_text();
                u=int.parse(str);
                if(u > 0 && conf.speakint < 15)
                {
                    u = 15;
                    ents[8].set_text("%u".printf(u));
                }
                if(conf.speakint != u)
                {
                    conf.settings.set_uint("speak-interval",u);

                }
                conf.rth_autoland = rthland.active;
                break;
            case 1002:
                break;
        }
        dialog.hide();
        return id;
    }
}

public class ShapeDialog : GLib.Object
{
    public struct ShapePoint
    {
        public double lat;
        public double lon;
        public double bearing;
        public int no;
    }

    private Gtk.Dialog dialog;
    private Gtk.SpinButton spin1;
    private Gtk.SpinButton spin2;
    private Gtk.SpinButton spin3;
    private Gtk.ComboBoxText combo;

    public ShapeDialog (Gtk.Builder builder, Gtk.Window? w=null)
    {
        dialog = builder.get_object ("shape-dialog") as Gtk.Dialog;
        dialog.set_transient_for(w);
        spin1  = builder.get_object ("shp_spinbutton1") as Gtk.SpinButton;
        spin2  = builder.get_object ("shp_spinbutton2") as Gtk.SpinButton;
        spin3  = builder.get_object ("shp_spinbutton3") as Gtk.SpinButton;
        combo  = builder.get_object ("shp-combo") as Gtk.ComboBoxText;
        spin2.adjustment.value = 0;
    }

    public ShapePoint[] get_points(double clat, double clon)
    {
        ShapePoint[] p = {};
        dialog.show_all();
        var id = dialog.run();
        switch(id)
        {
            case 1001:

                var npts = (int)spin1.adjustment.value;
                var radius = spin2.adjustment.value;
                var start = spin3.adjustment.value;
                var dtext = combo.get_active_id();
                int dirn = 1;

                if(dtext != null)
                    dirn = int.parse(dtext);

                radius = InputParser.get_scaled_real(radius.to_string());
                if(radius > 0)
                {
                    p = mkshape(clat, clon, radius, npts, start, dirn);
                }

                break;
            case 1002:
                break;
        }
        dialog.hide();
        return p;
    }

    public static ShapePoint[] mkshape(double clat, double clon,double radius,
                         int npts=6, double start = 0, int dirn=1)
    {
        double ang = start;
        double dint  = dirn*(360.0/npts);
        ShapePoint[] points= new ShapePoint[npts+1];
        radius /= 1852.0;
        for(int i =0; i <= npts; i++)
        {
            double lat,lon;
            Geo.posit(clat,clon,ang,radius,out lat, out lon);
            var p = ShapePoint() {no = i, lat=lat, lon=lon, bearing = ang};
            points[i] = p;
            ang = (ang + dint) % 360.0;
            if (ang < 0.0)
                ang += 360;
        }
        return points;
    }
}

public class RadioStatus : GLib.Object
{
    private enum Radio_modes
    {
        UNDEF = -1,
        RSSI = 1,
        THREEDR = 0
    }

    private Gtk.Label rxerr_label;
    private Gtk.Label fixerr_label;
    private Gtk.Label locrssi_label;
    private Gtk.Label remrssi_label;
    private Gtk.Label txbuf_label;
    private Gtk.Label noise_label;
    private Gtk.Label remnoise_label;
    public Gtk.Box box {get; private set;}
    private Gtk.Grid grid0;
    private Gtk.Grid grid1;
    private MSP_RADIO r;
    private Radio_modes mode;
    private Gtk.Label rssi_pct;
    private Gtk.Label rssi_value;
    private Gtk.LevelBar bar;

    public RadioStatus(Gtk.Builder builder)
    {
        mode = Radio_modes.UNDEF;

        grid0 = builder.get_object ("grid4a") as Gtk.Grid;
        rxerr_label = builder.get_object ("rxerrlab") as Gtk.Label;
        fixerr_label = builder.get_object ("fixerrlab") as Gtk.Label;
        locrssi_label = builder.get_object ("locrssilab") as Gtk.Label;
        remrssi_label = builder.get_object ("remrssilab") as Gtk.Label;
        txbuf_label = builder.get_object ("txbuflab") as Gtk.Label;
        noise_label = builder.get_object ("noiselab") as Gtk.Label;
        remnoise_label = builder.get_object ("remnoiselab") as Gtk.Label;
        grid1 = builder.get_object ("grid4b") as Gtk.Grid;
        bar = builder.get_object ("rssi_bar") as Gtk.LevelBar;
        bar.set_size_request (-1, 20);
        rssi_pct = builder.get_object ("rssi_pct") as Gtk.Label;
        rssi_value = builder.get_object ("rssi_val") as Gtk.Label;
        box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.pack_start(grid1, true, true,0);
        box.show_all();
    }

    private void unset_rssi_mode()
    {
        mode = Radio_modes.UNDEF;
    }

    private void set_modes(Radio_modes r)
    {
        var l = box.get_children();
        Gtk.Grid g = (r == Radio_modes.THREEDR) ? grid0 : grid1;
        if(l.first().data != g)
        {
            box.remove(l.first().data);
            box.pack_start(g, true,true,0);
        }
    }

    public void update_rssi(ushort rssi, bool visible)
    {
        if(visible)
        {
            if(mode !=  Radio_modes.RSSI)
                set_modes(Radio_modes.RSSI);
            uint fs = FlightBox.fh1/2;
            rssi_value.set_label("<span font='%u'>%s</span>".printf(fs,rssi.to_string()));
            ushort pct = rssi*100/1023;
            rssi_pct.set_label("<span font='%u'>%d%%</span>".printf(fs,pct));
            bar.set_value(rssi);
        }
    }

    public void update_ltm(LTM_SFRAME s,bool visible)
    {
        if(visible)
        {
            ushort rssi;
            rssi = 1023*s.rssi/254;
            update_rssi(rssi, true);
        }
    }

    private void display()
    {
        rxerr_label.set_label(r.rxerrors.to_string());
        fixerr_label.set_label(r.fixed_errors.to_string());
        locrssi_label.set_label(r.localrssi.to_string());
        remrssi_label.set_label(r.remrssi.to_string());
        txbuf_label.set_label(r.txbuf.to_string());
        noise_label.set_label(r.noise.to_string());
        remnoise_label.set_label(r.remnoise.to_string());
    }

    public void annul()
    {
        unset_rssi_mode();
        r = {0};
        clear();
    }

    private void clear()
    {
        rxerr_label.set_label("");
        fixerr_label.set_label("");
        locrssi_label.set_label("");
        remrssi_label.set_label("");
        txbuf_label.set_label("");
        noise_label.set_label("");
        remnoise_label.set_label("");
        rssi_pct.set_label("");
        rssi_value.set_label("");
        bar.set_value(0);
    }

    public void update(MSP_RADIO _r, bool visible)
    {
        r = _r;
        if(visible)
        {
            if(mode !=  Radio_modes.THREEDR)
                set_modes(Radio_modes.THREEDR);
            display();
        }

        if (Logger.is_logging)
        {
            Logger.radio(r);
        }
    }
}

public class NavStatus : GLib.Object
{
    private Gtk.Label gps_mode_label;
    private Gtk.Label nav_state_label;
    private Gtk.Label nav_action_label;
    private Gtk.Label nav_wp_label;
    private Gtk.Label nav_err_label;
    private Gtk.Label nav_tgt_label;
    private Gtk.Label nav_comp_gps_label;
    private Gtk.Label nav_altitude_label;
    private Gtk.Label nav_attitude_label;
    private bool enabled = false;
    public Gtk.Grid grid {get; private set;}
    private  Gtk.Label voltlabel;
    public Gtk.Box voltbox{get; private set;}
    private bool vinit = false;
    private bool mt_voice = false;
    private AudioThread mt = null;
    private bool have_cg = false;
    private bool have_hdr = false;
    private VCol vc;

    public static MSP_NAV_STATUS n {get; private set;}
    public static MSP_ATTITUDE atti {get; private set;}
    public static MSP_ALTITUDE alti {get; private set;}
    public static MSP_COMP_GPS cg {get; private set;}
    public static float volts {get; private set;}
    public static uint8 numsat {get; private set;}
    public static int16 hdr {get; private set;}
    public static bool modsat;

    public static uint8 xfmode {get; private set;}
    public static int mins {get; private set;}
    public static bool recip {get; private set;}
    public static string fmode;
    private static string ls_state = null;
    private static string ls_action = null;
    private static string ns_action = null;
    private static string ns_state = null;

    private int _vn;
    private int _fs;

    private int efdin;

    public enum SPK  {
        Volts = 1,
        GPS = 2,
        BARO = 4,
        ELEV = 8
    }

    public NavStatus(Gtk.Builder builder, VCol _vc)
    {
        xfmode = 255;
        numsat = 0;
        modsat = false;
        vc = _vc;
        _vn = -1;

        grid = builder.get_object ("grid3") as Gtk.Grid;
        gps_mode_label = builder.get_object ("gps_mode_lab") as Gtk.Label;
        nav_state_label = builder.get_object ("nav_status_label") as Gtk.Label;
        nav_action_label = builder.get_object ("nav_action_label") as Gtk.Label;
        nav_wp_label = builder.get_object ("nav_wp_label") as Gtk.Label;
        nav_err_label = builder.get_object ("nav_error_label") as Gtk.Label;
        nav_tgt_label = builder.get_object ("nav_bearing_label") as Gtk.Label;

        nav_comp_gps_label = builder.get_object ("comp_gps_label") as Gtk.Label;
        nav_altitude_label = builder.get_object ("altitude_label") as Gtk.Label;
        nav_attitude_label = builder.get_object ("attitude_label") as Gtk.Label;
        enabled = true;

        voltlabel = new Gtk.Label("");
//        voltlabel.xalign = 0.75f;
        voltbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
        voltbox.pack_start (voltlabel, true, true, 1);
        voltbox.size_allocate.connect((a) => {
                var fh1 = a.width/4;
                var fh2 = a.height / 2;
                _fs = (fh1 < fh2) ? fh1 : fh2;
            });

        voltlabel.set_use_markup (true);
        volt_update("n/a",-1, 0f,true);
        grid.show_all();
    }


    public void update_ltm_a(LTM_AFRAME a, bool visible)
    {
        if(enabled || Logger.is_logging)
        {
            hdr = a.heading;
            if(hdr < 0)
                hdr += 360;
            have_hdr = true;
            if(visible)
            {
               var str = "%d° / %d° / %d°".printf(a.roll, a.pitch, hdr);
                nav_attitude_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.attitude(a.roll,a.pitch,hdr);
            }
        }
    }

    public void update(MSP_NAV_STATUS _n, bool visible, uint8 flag = 0)
    {
        if(mt_voice == true)
        {
            var xnmode = n.nav_mode;
            var xnerr = n.nav_error;
            var xnwp = n.wp_number;

            n = _n;

            if(_n.nav_mode != 0 &&
               _n.nav_error != 0 &&
               _n.nav_error != 4 &&
               _n.nav_error != 5 &&
               _n.nav_error != 6 &&
               _n.nav_error != 7 &&
               _n.nav_error != 8 &&
               _n.nav_error != xnerr)
            {
                mt.message(AudioThread.Vox.NAV_ERR,true);
            }

            if((_n.nav_mode != xnmode) || (_n.nav_mode !=0 && _n.wp_number != xnwp))
            {
                mt.message(AudioThread.Vox.NAV_STATUS,true);
            }
        }

        if(visible)
        {
            var gstr = MSP.gps_mode(n.gps_mode);
            var n_action = n.action;
            var n_wpno = (n.nav_mode == 0) ? 0 : n.wp_number;
            var estr = MSP.nav_error(n.nav_error);
            var tbrg = n.target_bearing;
            ns_state = MSP.nav_state(n.nav_mode);
            ns_action = MSP.get_wpname((MSP.Action)n_action);

            gps_mode_label.set_label(gstr);
            set_nav_state_act();
            nav_wp_label.set_label("%d".printf(n_wpno));
            nav_err_label.set_label(estr);
            if(flag == 0)
                nav_tgt_label.set_label("%d".printf(tbrg));
            else
                nav_tgt_label.set_label("[%x]".printf(tbrg));
        }

        if (Logger.is_logging)
        {
            Logger.status(n);
        }
    }

    private void set_nav_state_act()
    {
        StringBuilder sb = new StringBuilder ();
        if (ns_state != null)
        {
            sb.append(ns_state);
            sb.append(" ");
        }
        if (ls_state != null)
            sb.append(ls_state);
        nav_state_label.set_label(sb.str);

        sb.assign("");
        if (ns_action != null)
        {
            sb.append(ns_action);
            sb.append(" ");
        }
        if (ls_action != null)
            sb.append(ls_action);

        nav_action_label.set_label(sb.str);
    }

    public void update_ltm_s(LTM_SFRAME s, bool visible)
    {
        if(enabled || Logger.is_logging)
        {
            uint8 armed = (s.flags & 1);
            uint8 failsafe = ((s.flags & 2) >> 1);
            uint8 fmode = (s.flags >> 2);

            ls_state = MSP.ltm_mode(fmode);
            ls_action = "%s %s".printf(((armed == 1) ? "armed" : "disarmed"),
                                     ((failsafe == 1) ? "failsafe" : ""));
            if(visible)
            {
                set_nav_state_act();
            }
            if(xfmode != fmode)
            {
                if(failsafe == 1)
                    mt.message(AudioThread.Vox.FAILSAFE,true);

                xfmode = fmode;
                    // only speak modes that are not in N-Frame
                if(mt_voice && ((xfmode > 0 && xfmode < 5) ||
                                xfmode == 8 || xfmode == 19))
                {
                    mt.message(AudioThread.Vox.LTM_MODE,true);
                }
            }

            if (Logger.is_logging)
            {
                var b = new StringBuilder ();
                b.append(ls_action.strip());
                b.append(" ");
                b.append(ls_state);
                Logger.ltm_sframe(s, b.str);
            }
        }
    }

    public void set_attitude(MSP_ATTITUDE _atti,bool visible)
    {
        atti = _atti;
        if(enabled || Logger.is_logging)
        {
            double dax;
            double day;
            dax = (double)(atti.angx)/10.0;
            day = (double)(atti.angy)/10.0;
            hdr = atti.heading;
            if(hdr < 0)
                hdr += 360;

            have_hdr = true;
            if(visible)
            {
                var str = "%.1f° / %.1f° / %d°".printf(dax, day, hdr);
                nav_attitude_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.attitude(dax,day,hdr);
            }
        }
    }

    public void set_altitude(MSP_ALTITUDE _alti, bool visible)
    {
        alti = _alti;
        if(enabled || Logger.is_logging)
        {
            double vario = alti.vario/10.0;
            double estalt = alti.estalt/100.0;
            if(visible)
            {
                var str = "%.1f%s / %.1f%s".printf(
                    Units.distance(estalt),
                    Units.distance_units(),
                    Units.va_speed(vario),
                    Units.va_speed_units());
                nav_altitude_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.altitude(estalt,vario);
            }
        }
    }

    public void set_mav_attitude(Mav.MAVLINK_ATTITUDE m, bool visible)
    {
        double dax;
        double day;
        dax = m.roll * 57.29578;
        day = m.pitch * 57.29578;
        hdr = (int16) (m.yaw * 57.29578);

        if(hdr < 0)
            hdr += 360;

        have_hdr = true;
        if(visible)
        {
            var str = "%.1f° / %.1f° / %d°".printf(dax, day, hdr);
            nav_attitude_label.set_label(str);
        }
        if(Logger.is_logging)
        {
            Logger.mav_attitude(m);
        }
    }

    public void  set_mav_altitude(Mav.MAVLINK_VFR_HUD m, bool visible)
    {
        alti = {(int32)(m.alt * 100), (int16)(m.climb*10)};
        if(visible)
        {
            var str = "%.1f%s / %.1f%s".printf(
                Units.distance(m.alt),
                Units.distance_units(),
                Units.va_speed(m.climb),
                Units.va_speed_units());
            nav_altitude_label.set_label(str);
        }
        if(Logger.is_logging)
        {
            Logger.mav_vfr_hud(m);
        }
    }

    public void comp_gps(MSP_COMP_GPS _cg, bool visible)
    {
        cg = _cg;
        have_cg = true;
        if(enabled || Logger.is_logging)
        {
            var brg = cg.direction;
            if(brg < 0)
                brg += 360;

            if(visible)
            {
                var str = "%.0f%s / %d° / %s".printf(
                    Units.distance(cg.range),
                    Units.distance_units(),
                    brg,
                    (cg.update == 0) ? "false" : "true");
                nav_comp_gps_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.comp_gps(brg,cg.range,cg.update);
            }
        }
    }

    public void volt_update(string s, int n, float v, bool visible)
    {
        volts = v;
        if (n == -1)
            n = vc.levels.length-1;

        if(visible)
        {
            if(n != _vn)
            {
                var lsc = voltlabel.get_style_context();
                if(_vn != -1)
                    lsc.remove_class(vc.levels[_vn].colour);
                lsc.add_class(vc.levels[n].colour);
                _vn = n;
            }
            voltlabel.set_label("<span font_family='monospace' font='%d'>%s</span>".printf(_fs,s));
        }
    }

    public void update_fmode(string _fmode)
    {
        fmode = _fmode;
        if(mt_voice)
        {
            mt.message(AudioThread.Vox.FMODE,true);
        }
    }

    public void update_duration(int _mins)
    {
        mins = _mins;
        if(mt_voice)
        {
            mt.message(AudioThread.Vox.DURATION);
        }
    }

    public void sats(uint8 nsats, bool urgent=false)
    {
        numsat = nsats;
        if(mt != null)
        {
            mt.message(AudioThread.Vox.MODSAT,urgent);
        }
    }

    public void hw_failure(uint8 bad)
    {
        if(mt != null)
        {
            AudioThread.Vox c;
            if(bad == 0)
                c = AudioThread.Vox.HW_OK;
            else
                c = AudioThread.Vox.HW_BAD;
            mt.message(c, (bad == 1));
        }
    }

    public void announce(uint8 mask, bool _recip)
    {
        recip = _recip;

        if(have_hdr)
        {
            mt.message(AudioThread.Vox.HEADING);
        }
        if(((mask & SPK.GPS) == SPK.GPS) && have_cg)
        {
            mt.message(AudioThread.Vox.RANGE_BRG);
        }
        if((mask & SPK.ELEV) == SPK.ELEV)
        {
            mt.message(AudioThread.Vox.ELEVATION);
        }
        else if((mask & SPK.BARO) == SPK.BARO)
        {
            mt.message(AudioThread.Vox.BARO);
        }
        if((mask & SPK.Volts) == SPK.Volts && volts > 0.0)
        {
            mt.message(AudioThread.Vox.VOLTAGE);
        }
    }

    public void alert_home_moved()
    {
        mt.message(AudioThread.Vox.HOME_CHANGED, true);
    }

    public void gps_crit()
    {
        mt.message(AudioThread.Vox.GPS_CRIT, true);
    }

    public void cg_on()
    {
        have_cg = true;
    }

    public void reset_states()
    {
        ls_state = null;
        ls_action = null;
        ns_state = null;
        ns_action = null;
    }

    public void reset()
    {
        have_cg = false;
        have_hdr = false;
        volts = 0;
        reset_states();
    }

    public void annul()
    {
        reset();
        alti = {0};
        cg = {0};
        hdr = 0;
        volt_update("n/a",-1, 0f,true);
    }

    public void logspeak_init (string? voice, bool use_en = false)
    {
        if(vinit == false)
        {
            efdin=0;
            vinit = true;
            if(voice == null)
                voice = "default";
            var si = speech_init(voice);
            MWPLog.message("Using %s for speech\n",
                           (si == 0) ? "espeak" : (si == 1) ? "speechd" : "none");
        }
        if (mt != null)
        {
            logspeak_close();
        }
        mt = new AudioThread();
        mt.start(use_en, efdin);
        mt_voice=true;
    }

    public void logspeak_close()
    {
        mt_voice=false;
        mt.clear();
        mt.message(AudioThread.Vox.DONE);
        mt.thread.join ();
        mt = null;
    }
}

public class AudioThread : Object {
    public enum Vox
    {
        DONE=1,
        NAV_ERR,
        NAV_STATUS,
        DURATION,
        FMODE,
        RANGE_BRG,
        ELEVATION,
        BARO,
        HEADING,
        VOLTAGE,
        MODSAT,
        LTM_MODE,
        GPS_CRIT,
        FAILSAFE,
        HW_OK,
        HW_BAD,
        HOME_CHANGED
    }

    private Timer timer;
    private double lsat_t;
    private uint lsats;
    private bool use_en = false;
    private int efd;

    private AsyncQueue<Vox> msgs;
    public Thread<int> thread {private set; get;}

    public AudioThread () {
        msgs = new AsyncQueue<Vox> ();
    }

    private string str_zero(string str)
    {
        if(str[-3:-1] == ".0")
        {
            return str[0:-2];
        }
        else
        {
            return str;
        }
    }

    public void message(Vox c, bool urgent=false)
    {
        if (msgs.length() > 10)
        {
            clear();
            MWPLog.message("cleared voice queue\n");
        }
        if(!urgent)
            msgs.push(c);
        else
        {
            msgs.push_front(c);
        }
    }

    public void clear()
    {
        while (msgs.try_pop() != (Vox)null)
            ;
    }

    public void start(bool _use_en = false, int _efd = 0)
    {
        efd = _efd;
        use_en = _use_en;
        lsats = 255;
        timer = new Timer();
        timer.start();
        lsat_t = timer.elapsed();
        thread = new Thread<int> ("mwp audio", () => {
                Vox c;
                while((c = msgs.pop()) != Vox.DONE)
                {
                    string s=null;
                    switch(c)
                    {
                        case Vox.HW_OK:
                            s = "Sensors OK";
                            break;
                        case Vox.HW_BAD:
                            s = "Sensor Failure";
                            break;
                        case Vox.NAV_ERR:
                            s = MSP.nav_error(NavStatus.n.nav_error);
                            break;
                        case Vox.GPS_CRIT:
                            s = "GPS Critical Failure";
                            break;
                        case Vox.HOME_CHANGED:
                            s = "Warning: Home position change";
                            break;
                        case Vox.NAV_STATUS:
                            switch(NavStatus.n.nav_mode)
                            {
                                case 0:
                                    s = "Manual mode.";
                                    break;
                                case 1:
                                    s = "Return to home initiated.";
                                    break;
                                case 2:
                                    s = "Navigating to home position.";
                                    break;
                                case 3:
                                    s = "Infinite position hold.";
                                    break;
                                case 4:
                                    s = "Timed position hold.";
                                    break;
                                case 5:
                                    var wpno = NavStatus.n.wp_number;
                                    if(wpno == 0)
                                        s = "Starting Mission";
                                    else
                                        s = "Navigating to waypoint %d.".printf(wpno);
                                    break;
                                case 7:
                                    s = "Starting jump for %d".printf(NavStatus.n.wp_number);
                                    break;
                                case 8:
                                    s = "Starting to land.";
                                    break;
                                case 9:
                                    s = "Landing in progress.";
                                    break;
                                case 10:
                                    s = "Landed.";
                                    break;
                            }
                            break;
                        case Vox.DURATION:
                            var ms = (NavStatus.mins > 1) ? "minutes" : "minute";
                            s = "%d %s".printf(NavStatus.mins, ms);
                            break;
                        case Vox.FMODE:
                            s = "%s mode".printf(NavStatus.fmode);
                            break;
                        case Vox.RANGE_BRG:
                            var brg = NavStatus.cg.direction;
                            if(brg < 0)
                                brg += 360;
                            if(NavStatus.recip)
                                brg = ((brg + 180) % 360);
                            s = "Range %.0f. Bearing %d.".printf(
                                Units.distance(NavStatus.cg.range),
                                brg);
                            break;
                        case Vox.ELEVATION:
                            s = "Elevation %.0f.".printf(Units.distance(GPSInfo.elev));
                            s = str_zero(s);
                            break;
                        case Vox.BARO:
                            double estalt = (double)NavStatus.alti.estalt/100.0;
                            if(estalt < 0.0 || estalt > 20.0)
                                estalt = Math.round(estalt);
                            s  = "Altitude %.1f.".printf(Units.distance(estalt));
                            s = str_zero(s);
                            break;
                        case Vox.HEADING:
                            s = "Heading %d.".printf(NavStatus.hdr);
                            break;
                        case Vox.VOLTAGE:
                            s = "Voltage %.1f.".printf( NavStatus.volts);
                            s = str_zero(s);
                            break;
                        case Vox.MODSAT:
                            var now = timer.elapsed();
                            if(lsats != NavStatus.numsat || (now - lsat_t) > 10)
                            {
                                string ss = "";
                                if(NavStatus.numsat != 1)
                                    ss = "s";
                                s = "%d satellite%s.".printf(NavStatus.numsat,ss);
                                lsats = NavStatus.numsat;
                                lsat_t = now;
                            }
                            break;
                        case Vox.LTM_MODE:
                            var xfmode = NavStatus.xfmode;
                            if(((xfmode > 0 && xfmode < 5) || xfmode == 8 ||
                                xfmode == 19))
                                s = MSP.ltm_mode(xfmode);
                            break;
                        case Vox.FAILSAFE:
                            s="FAIL SAFE";
                            break;

                        default:
                            break;
                    }
                    if(s != null)
                    {
                        if(use_en)
                            s = s.replace(",",".");
                        if(efd != 0)
                        {
                            Posix.write(efd, s, s.length);
                            Posix.write(efd, "\r\n", 2);
                        }
                        else
                            speech_say(s);
//                        MWPLog.message("say %d \"%s\"\n", efd, s);
                    }
                }
                return 0;
            });
    }
}

public class NavConfig : GLib.Object
{
    private Gtk.Window parent;
    private Gtk.Builder builder;

    private Gtk.Window window;
    private bool visible;
    private MWPlanner.NAVCAPS typ;

        // MW variables
    private Gtk.CheckButton nvcb1_01;
    private Gtk.CheckButton nvcb1_02;
    private Gtk.CheckButton nvcb1_03;
    private Gtk.CheckButton nvcb1_04;
    private Gtk.CheckButton nvcb1_05;
    private Gtk.CheckButton nvcb1_06;
    private Gtk.CheckButton nvcb1_07;
    private Gtk.CheckButton nvcb1_08;
    private Gtk.CheckButton nvcb2_01;
    private Gtk.CheckButton nvcb2_02;
    private Gtk.Entry wp_radius;
    private Gtk.Entry safe_wp_dist;
    private Gtk.Entry nav_max_alt;
    private Gtk.Entry nav_speed_max;
    private Gtk.Entry nav_speed_min;
    private Gtk.Entry crosstrack_gain;
    private Gtk.Entry nav_bank_max;
    private Gtk.Entry rth_altitude;
    private Gtk.Entry land_speed;
    private Gtk.Entry fence;
    private Gtk.Entry max_wp_no;
    private uint8 _xtrack;
    private uint8 _maxwp;
    public signal void mw_navconf_event (MSP_NAV_CONFIG ncu);

        // iNav MR variables

    private Gtk.Entry inav_max_speed;
    private Gtk.Entry inav_mr_max_climb;
    private Gtk.Entry inav_mr_man_speed;
    private Gtk.Entry inav_mr_climb_rate;
    private Gtk.Switch inav_mr_midthr_alt;
    private Gtk.ComboBoxText inav_mr_control_mode;
    private Gtk.Entry inav_mc_bank_angle;
    private Gtk.Entry inav_mr_hover_throttle;

    public signal void mr_nav_poshold_event (MSP_NAV_POSHOLD nph);

    private Gtk.Window? inav_fw_open(Gtk.Builder builder)
    {
//        Gtk.Window w = builder.get_object ("inav_mr_conf") as Gtk.Window;
        return null;
    }

    public void mr_update(MSP_NAV_POSHOLD pcfg)
    {
        inav_mr_midthr_alt.set_active(pcfg.nav_use_midthr_for_althold == 1);
        inav_max_speed.set_text(pcfg.nav_max_speed.to_string());
        inav_mr_max_climb.set_text(pcfg.nav_max_climb_rate.to_string());
        inav_mr_man_speed.set_text(pcfg.nav_manual_speed.to_string());
        inav_mr_climb_rate.set_text(pcfg.nav_manual_climb_rate.to_string());
        inav_mr_control_mode.active = pcfg.nav_user_control_mode;
        inav_mc_bank_angle.set_text(pcfg.nav_mc_bank_angle.to_string());
        inav_mr_hover_throttle.set_text(pcfg.nav_mc_hover_thr.to_string());
    }

    private MSP_NAV_POSHOLD inav_mr_get_values()
    {
        MSP_NAV_POSHOLD pcfg = MSP_NAV_POSHOLD();
        pcfg.nav_use_midthr_for_althold = (inav_mr_midthr_alt.active) ? 1 : 0;
        pcfg.nav_max_speed = (uint16)int.parse(inav_max_speed.get_text());
        pcfg.nav_max_climb_rate = (uint16)int.parse(inav_mr_max_climb.get_text());
        pcfg.nav_manual_speed = (uint16)int.parse(inav_mr_man_speed.get_text());
        pcfg.nav_manual_climb_rate = (uint16)int.parse(inav_mr_climb_rate.get_text());
        pcfg.nav_user_control_mode = (uint8)inav_mr_control_mode.active;
        pcfg.nav_mc_bank_angle = (uint8)int.parse(inav_mc_bank_angle.get_text());
        pcfg.nav_mc_hover_thr = (uint16)int.parse(inav_mr_hover_throttle.get_text());
        return pcfg;
    }

        private Gtk.Window inav_mr_open(Gtk.Builder builder)
    {
        Gtk.Window w = builder.get_object ("inav_mr_conf") as Gtk.Window;
        var button = builder.get_object ("inav_mr_close") as Gtk.Button;
        button.clicked.connect(() => {
                w.hide();
            });

        var apply = builder.get_object ("inav_mr_apply") as Gtk.Button;
        apply.clicked.connect(() => {
                mr_nav_poshold_event(inav_mr_get_values());
            });

        inav_max_speed = builder.get_object ("inav_max_speed") as Gtk.Entry;
        inav_mr_max_climb = builder.get_object ("inav_mr_max_climb") as Gtk.Entry;
        inav_mr_man_speed = builder.get_object ("inav_mr_man_speed") as Gtk.Entry;
        inav_mr_climb_rate = builder.get_object ("inav_mr_climb_rate") as Gtk.Entry;
        inav_mr_control_mode = builder.get_object ("inav_mr_control_mode") as Gtk.ComboBoxText;
        inav_mc_bank_angle = builder.get_object ("inav_mc_bank_angle") as Gtk.Entry;
        inav_mr_midthr_alt = builder.get_object ("inav_mr_midthr_alt") as Gtk.Switch;
        inav_mr_hover_throttle = builder.get_object ("inav_mr_hover_throttle") as Gtk.Entry;
        return w;
    }

    private Gtk.Window mw_open(Gtk.Builder builder)
    {
        Gtk.Window w = builder.get_object ("nc_window") as Gtk.Window;
        var button = builder.get_object ("nc_close") as Gtk.Button;
        button.clicked.connect(() => {
                w.hide();
            });

        var apply = builder.get_object ("nc_apply") as Gtk.Button;
        apply.clicked.connect(() => {
                MSP_NAV_CONFIG ncu = MSP_NAV_CONFIG();
                if (nvcb1_01.active)
                    ncu.flag1 |= 0x01;
                if (nvcb1_02.active)
                    ncu.flag1 |= 0x02;
                    // Logic inverted
                if (nvcb1_03.active == false)
                    ncu.flag1 |= 0x04;
                if (nvcb1_04.active)
                    ncu.flag1 |= 0x08;
                if (nvcb1_05.active)
                    ncu.flag1 |= 0x10;
                if (nvcb1_06.active)
                    ncu.flag1 |= 0x20;
                if (nvcb1_07.active)
                    ncu.flag1 |= 0x40;
                if (nvcb1_08.active)
                    ncu.flag1 |= 0x80;

                if (nvcb2_01.active)
                    ncu.flag2 |= 0x01;
                if (nvcb2_02.active)
                    ncu.flag2 |= 0x02;

                uint16 u16;
                u16 = (uint16)int.parse(wp_radius.get_text());
                ncu.wp_radius = u16;
                u16 = (uint16) int.parse(safe_wp_dist.get_text());
                ncu.safe_wp_distance = u16;
                u16 = (uint16)int.parse(nav_max_alt.get_text());
                ncu.nav_max_altitude = u16;
                u16 = (uint16)int.parse(nav_speed_max.get_text());
                ncu.nav_speed_max = u16;
                u16 = (uint16)int.parse(nav_speed_min.get_text());
                ncu.nav_speed_min = u16;

                string s = nav_bank_max.get_text();
                u16 = (uint16)(g_strtod(s,null)*100);
                ncu.nav_bank_max = u16;
                u16 = (uint16)int.parse(rth_altitude.get_text());
                ncu.rth_altitude = u16;
                ncu.land_speed = (uint8)int.parse(land_speed.get_text());
                u16 = (uint16)int.parse(fence.get_text());
                ncu.fence = u16;
                ncu.crosstrack_gain = _xtrack;
                ncu.max_wp_number = _maxwp;
                mw_navconf_event(ncu);
            });

        nvcb1_01 = builder.get_object ("nvcb1_01") as Gtk.CheckButton;
        nvcb1_02 = builder.get_object ("nvcb1_02") as Gtk.CheckButton;
        nvcb1_03 = builder.get_object ("nvcb1_03") as Gtk.CheckButton;
        nvcb1_04 = builder.get_object ("nvcb1_04") as Gtk.CheckButton;
        nvcb1_05 = builder.get_object ("nvcb1_05") as Gtk.CheckButton;
        nvcb1_06 = builder.get_object ("nvcb1_06") as Gtk.CheckButton;
        nvcb1_07 = builder.get_object ("nvcb1_07") as Gtk.CheckButton;
        nvcb1_08 = builder.get_object ("nvcb1_08") as Gtk.CheckButton;
        nvcb2_01 = builder.get_object ("nvcb2_01") as Gtk.CheckButton;
        nvcb2_02 = builder.get_object ("nvcb2_02") as Gtk.CheckButton;
        wp_radius = builder.get_object ("wp_radius") as Gtk.Entry;
        safe_wp_dist = builder.get_object ("safe_wp_dist") as Gtk.Entry;
        nav_max_alt = builder.get_object ("nav_max_alt") as Gtk.Entry;
        nav_speed_max = builder.get_object ("nav_speed_max") as Gtk.Entry;
        nav_speed_min = builder.get_object ("nav_speed_min") as Gtk.Entry;
        crosstrack_gain = builder.get_object ("crosstrack_gain") as Gtk.Entry;
        nav_bank_max = builder.get_object ("nav_bank_max") as Gtk.Entry;
        rth_altitude  = builder.get_object ("rth_altitude") as Gtk.Entry;
        land_speed = builder.get_object ("land_speed") as Gtk.Entry;
        fence = builder.get_object ("fence") as Gtk.Entry;
        max_wp_no = builder.get_object ("max_wp_no") as Gtk.Entry;
        return w;
    }


    public NavConfig (Gtk.Window _parent, Gtk.Builder _builder)
    {
        builder = _builder;
        parent = _parent;
    }

    public void setup (MWPlanner.NAVCAPS _typ)
    {
        if(window != null && typ != _typ)
        {
            window.destroy();
            window = null;
        }
        typ = _typ;
        if(window == null)
        {
            if(typ == MWPlanner.NAVCAPS.INAV_MR)
                window = inav_mr_open(builder);
            else if(typ == MWPlanner.NAVCAPS.INAV_FW)
                window = inav_fw_open(builder);
            else
                window = mw_open(builder);
        }
        if(window != null)
        {
            window.set_transient_for(parent);
            window.delete_event.connect (() => {
                    window.hide();
                    visible = false;
                    return true;
                });
        }
    }

    public void mw_update(MSP_NAV_CONFIG nc)
    {
        nvcb1_01.set_active ((nc.flag1 & 0x01) == 0x01);
        nvcb1_02.set_active ((nc.flag1 & 0x02) == 0x02);
            // Logic deliberately inverted
        nvcb1_03.set_active ((nc.flag1 & 0x04) != 0x04);
        nvcb1_04.set_active ((nc.flag1 & 0x08) == 0x08);
        nvcb1_05.set_active ((nc.flag1 & 0x10) == 0x10);
        nvcb1_06.set_active ((nc.flag1 & 0x20) == 0x20);
        nvcb1_07.set_active ((nc.flag1 & 0x40) == 0x40);
        nvcb1_08.set_active ((nc.flag1 & 0x80) == 0x80);
        nvcb2_01.set_active ((nc.flag2 & 0x01) == 0x01);
        nvcb2_02.set_active ((nc.flag2 & 0x02) == 0x02);

        wp_radius.set_text(nc.wp_radius.to_string());
        safe_wp_dist.set_text(nc.safe_wp_distance.to_string());
        nav_max_alt.set_text(nc.nav_max_altitude.to_string());
        nav_speed_max.set_text(nc.nav_speed_max.to_string());
        nav_speed_min.set_text(nc.nav_speed_min.to_string());
        crosstrack_gain.set_text("%.2f".printf((double)nc.crosstrack_gain/100.0));
        nav_bank_max.set_text("%.2f".printf((double)nc.nav_bank_max/100.0));
        rth_altitude.set_text(nc.rth_altitude.to_string());
        land_speed.set_text(nc.land_speed.to_string());
        fence.set_text(nc.fence.to_string());
        max_wp_no.set_text(nc.max_wp_number.to_string());
        _xtrack = nc.crosstrack_gain;
        _maxwp = nc.max_wp_number;
    }

    public void hide()
    {
        window.hide();
        visible = false;
    }

    public void show()
    {
        visible = true;
        window.show_all();
    }
}

public class GPSInfo : GLib.Object
{
    private Gtk.Label nsat_lab;
    private Gtk.Label lat_lab;
    private Gtk.Label lon_lab;
    private Gtk.Label alt_lab;
    private Gtk.Label dirn_lab;
    private Gtk.Label speed_lab;
    private double _dlon = 0;
    private double _dlat = 0;
    private double ddm;

    public static double lat {get; private set;}
    public static double lon {get; private set;}
    public static double cse {get; private set;}
    public static double spd {get; private set;}
    public static int nsat {get; private set;}
    public static int16 elev {get; private set;}
    public static uint8 fix;
    public static double hdop = -1.0;


    public GPSInfo(Gtk.Grid grid)
    {
        var lab = new Gtk.Label("No. Satellites");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 0, 1, 1);
        nsat_lab = new Gtk.Label("-1");
        grid.attach(nsat_lab, 1, 0, 1, 1);

        lab = new Gtk.Label("Latitude");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 1, 1, 1);
        lat_lab = new Gtk.Label("--.------");
        lat_lab.halign = Gtk.Align.START;
        lat_lab.valign = Gtk.Align.START;
        grid.attach(lat_lab, 1, 1, 1, 1);

        lab = new Gtk.Label("Longitude");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 2, 1, 1);
        lon_lab = new Gtk.Label("---.------");
        lon_lab.halign = Gtk.Align.START;
        lon_lab.valign = Gtk.Align.START;
        grid.attach(lon_lab, 1, 2, 1, 1);

        lab = new Gtk.Label("Altitude");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 3, 1, 1);
        alt_lab = new Gtk.Label("---");
        alt_lab.halign = Gtk.Align.START;
        alt_lab.valign = Gtk.Align.START;
        grid.attach(alt_lab, 1, 3, 1, 1);

        lab = new Gtk.Label("Direction");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 4, 1, 1);
        dirn_lab = new Gtk.Label("---");
        dirn_lab.halign = Gtk.Align.START;
        dirn_lab.valign = Gtk.Align.START;
        grid.attach(dirn_lab, 1, 4, 1, 1);

        lab = new Gtk.Label("Speed");
        lab.halign = Gtk.Align.START;
        lab.valign = Gtk.Align.START;
        grid.attach(lab, 0, 5, 1, 1);
        speed_lab = new Gtk.Label("--.-");
        speed_lab.halign = Gtk.Align.START;
        speed_lab.valign = Gtk.Align.START;
        grid.attach(speed_lab, 1, 5, 1, 1);
        grid.show_all();
    }

    public void set_hdop(double _hdop)
    {
        hdop = _hdop;
    }

    public int update_mav_gps(Mav.MAVLINK_GPS_RAW_INT m, bool dms,bool visible, out double _ddm)
    {
        lat = m.lat/10000000.0;
        lon = m.lon/10000000.0;
        calc_cse_dist_delta(lat,lon);
        _ddm = ddm;
        double dalt = m.alt/1000.0;
        double cse = (m.cog == 0xffff) ? 0 : m.cog/100.0;
        spd  = (m.vel == 0xffff) ? 0 : m.vel/100.0;
        elev = (int16)Math.lround(dalt);
        nsat = m.satellites_visible;
        fix = m.fix_type;
        if(m.eph != 65535)
            hdop = m.eph / 100.0; // sort of

        var nsatstr = "%d (%sfix)".printf(m.satellites_visible, (m.fix_type < 2) ? "no" : "");
         if(visible)
        {
            nsat_lab.set_label(nsatstr);
            lat_lab.set_label(PosFormat.lat(lat,dms));
            lon_lab.set_label(PosFormat.lon(lon,dms));
            speed_lab.set_label(
                "%.0f %s".printf(
                    Units.speed(spd), Units.speed_units()
                                 ));
            alt_lab.set_label("%.1f %s".printf(
                                  Units.distance(dalt), Units.distance_units()));

            dirn_lab.set_label("%.1f °".printf(cse));
        }

        if(Logger.is_logging)
        {
            Logger.mav_gps_raw_int (m);
        }

        return m.fix_type;
    }

    private double calc_cse_dist_delta(double lat, double lon)
    {
        double cse = 0;
        if(_dlat != 0 && _dlon != 0)
        {
            double d;
            Geo.csedist(_dlat, _dlon, lat, lon, out d, out cse);
            ddm = d * 1852.0;
        }
        else
            ddm = 0.0;
        _dlat = lat;
        _dlon = lon;
        return cse;
    }

    public int update_ltm(LTM_GFRAME g, bool dms,bool visible, uint16 hdop, out double _ddm)
    {
        lat = g.lat/10000000.0;
        lon = g.lon/10000000.0;
        var cse =  calc_cse_dist_delta(lat,lon);
        _ddm = ddm;
        spd =  g.speed;
        double dalt = g.alt/100.0;
        fix = (g.sats & 3);
        nsat = (g.sats >> 2);
        var nsatstr = "%d (%sfix)".printf(nsat, Units.fix(fix));
        elev = (int16)Math.lround(dalt);

        if(visible)
        {
            nsat_lab.set_label(nsatstr);
            lat_lab.set_label(PosFormat.lat(lat,dms));
            lon_lab.set_label(PosFormat.lon(lon,dms));
            speed_lab.set_label(
                "%.0f %s".printf(
                    Units.speed(spd), Units.speed_units()
                                 ));
            alt_lab.set_label("%.1f %s".printf(
                                  Units.distance(dalt), Units.distance_units()));

            dirn_lab.set_label("%.1f °".printf(cse));
        }

        if(Logger.is_logging)
        {
            Logger.raw_gps(lat,lon,cse,spd, elev, fix, (uint8)nsat, hdop);
        }
        return fix;
    }

    public int update(MSP_RAW_GPS g, bool dms, bool visible, out double _ddm)
    {
        lat = g.gps_lat/10000000.0;
        lon = g.gps_lon/10000000.0;

        calc_cse_dist_delta(lat,lon);
        _ddm = ddm;
        spd = g.gps_speed/100.0;
        cse = g.gps_ground_course/10.0;
        nsat = g.gps_numsat;
        fix = g.gps_fix;

        if(Logger.is_logging)
        {
            Logger.raw_gps(lat,lon,cse,spd,
                           g.gps_altitude,
                           g.gps_fix,
                           g.gps_numsat,
                           g.gps_hdop);
        }

        if(visible)
        {
            var nsatstr = "%d (%sfix)".printf(g.gps_numsat,
                                              (g.gps_fix==0) ? "no" : "");
            nsat_lab.set_label(nsatstr);
            alt_lab.set_label("%0.f %s".printf(
                                  Units.distance(g.gps_altitude),
                                  Units.distance_units()
                                               ));

            lat_lab.set_label(PosFormat.lat(lat,dms));
            lon_lab.set_label(PosFormat.lon(lon,dms));

            speed_lab.set_label("%.1f %s".printf(
                                    Units.speed(spd),
                                    Units.speed_units()
                                    ));
            dirn_lab.set_label("%.1f °".printf(cse));
        }
        return g.gps_fix;
    }

    public void annul()
    {
        nsat_lab.set_label("-1");
        lat_lab.set_label("--.------");
        lon_lab.set_label("---.------");
        alt_lab.set_label("---");
        dirn_lab.set_label("---");
        speed_lab.set_label("--.-");
        _dlat = _dlon = 0;
        hdop = -1.0;
        lat = lon = cse = spd = nsat = elev = fix  = 0;
    }
}
