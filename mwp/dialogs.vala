
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
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


extern void espeak_init(char *voice);
extern void espeak_say(char *text);
//extern void espeak_terminate();

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
                dlat = double.parse(dlt_entry1.get_text());
                dlon = double.parse(dlt_entry2.get_text());
                dalt = int.parse(dlt_entry3.get_text());
                res = true;
                break;

            case 1002:
                break;
        }
        dialog.hide();
        return res;
    }

}

public class PrefsDialog : GLib.Object
{
    private Gtk.Dialog dialog;
    private Gtk.Entry[]ents = {};
    private Gtk.CheckButton dmscb;

    public PrefsDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("prefs-dialog") as Gtk.Dialog;
        for (int i = 1; i < 10; i++)
        {
            var id = "prefentry%d".printf(i);
            var e = builder.get_object (id) as Gtk.Entry;
            ents += e;
        }
        dialog.set_default_size (640, 320);
        dmscb = builder.get_object ("checkbutton3") as Gtk.CheckButton;
    }

    public void run_prefs(ref MWPSettings conf)
    {
        if(conf.devices != null)
        {
            var delimiter = ", ";
            StringBuilder sb = new StringBuilder ();
            foreach (string s in conf.devices)
            {
                sb.append(s);
                sb.append(delimiter);
            }
            sb.truncate (sb.len - delimiter.length);
            ents[0].set_text(sb.str);
        }
        ents[1].set_text("%.6f".printf(conf.latitude));
        ents[2].set_text("%.6f".printf(conf.longitude));
        ents[3].set_text("%u".printf(conf.loiter));
        ents[4].set_text("%u".printf(conf.altitude));
        ents[5].set_text("%.2f".printf(conf.nav_speed));
        ents[6].set_text(conf.defmap);
        ents[7].set_text("%u".printf(conf.zoom));
        ents[8].set_text("%u".printf(conf.speakint));
        dmscb.set_active(conf.dms);

        dialog.show_all ();
        var id = dialog.run();
        switch(id)
        {
            case 1001:
                var str = ents[0].get_text();
                var strs = str.split(",");
                for(int i=0; i<strs.length;i++)
                {
                    strs[i] = strs[i].strip();
                }
                conf.devices = strs;
                str = ents[1].get_text();
                conf.latitude=double.parse(str);
                str = ents[2].get_text();
                conf.longitude=double.parse(str);
                str = ents[3].get_text();
                conf.loiter=int.parse(str);
                str = ents[4].get_text();
                conf.altitude=int.parse(str);
                str = ents[5].get_text();
                conf.nav_speed=double.parse(str);
                str = ents[6].get_text();
                conf.defmap=str;
                str = ents[7].get_text();
                conf.zoom=int.parse(str);
                conf.dms = dmscb.active;
                str = ents[8].get_text();
                conf.speakint=int.parse(str);
                if(conf.speakint > 0 && conf.speakint < 15)
                {
                    conf.speakint = 15;
                    ents[8].set_text("%u".printf(conf.speakint));
                }
                conf.save_settings();
                break;
            case 1002:
                break;
        }
        dialog.hide();
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

    private ShapePoint[] points;
    private Gtk.Dialog dialog;
    private Gtk.SpinButton spin1;
    private Gtk.SpinButton spin2;
    private Gtk.SpinButton spin3;
    private Gtk.ComboBoxText combo;

    public ShapeDialog(Gtk.Builder builder)
    {
        dialog = builder.get_object ("shape-dialog") as Gtk.Dialog;
        spin1  = builder.get_object ("shp_spinbutton1") as Gtk.SpinButton;
        spin2  = builder.get_object ("shp_spinbutton2") as Gtk.SpinButton;
        spin3  = builder.get_object ("shp_spinbutton3") as Gtk.SpinButton;
        combo  = builder.get_object ("shp-combo") as Gtk.ComboBoxText;
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

                if(radius > 0)
                {
                    radius /= 1852.0;
                    mkshape(clat, clon, radius, npts, start, dirn);
                    p = points;
                }

                break;
            case 1002:
                break;
        }
        dialog.hide();
        return p;
    }

    private void mkshape(double clat, double clon,double radius,
                         int npts=6, double start = 0, int dirn=1)
    {
        double ang = start;
        double dint  = dirn*(360.0/npts);
        points= {};
        for(int i =0; i <= npts; i++)
        {
            double lat,lon;
            Geo.posit(clat,clon,ang,radius,out lat, out lon);
            var p = ShapePoint() {no = i, lat=lat, lon=lon, bearing = ang};
            points += p;
            ang = (ang + dint) % 360.0;
            if (ang < 0.0)
                ang += 360;
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
    private bool visible = false;
    public Gtk.Grid grid {get; private set;}
    private Gdl.DockItem di;
    private MSP_NAV_STATUS n;
    private MSP_ATTITUDE atti;
    private MSP_ALTITUDE alti;
    private MSP_COMP_GPS cg;
    private float volts;
    private  Gtk.Label voltlabel;
    public Gtk.Box voltbox{get; private set;}
    private Gdk.RGBA[] colors;
    private bool vinit = false;
    private bool mt_voice = false;
    private  AudioThread mt;

    public enum SPK  {
        Volts = 1,
        GPS = 2,
        BARO = 4
    }

    public NavStatus(Gtk.Builder builder)
    {
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
        visible = true;

        voltlabel = new Gtk.Label("");
        voltbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
        voltlabel.set_use_markup (true);
        voltbox.pack_start (voltlabel, true, true, 1);
        colors = new Gdk.RGBA[5];
        colors[0].parse("green");
        colors[1].parse("yellow");
        colors[2].parse("orange");
        colors[3].parse("red");
        colors[4].parse("white");
        volt_update("n/a",4, 0f);
    }

    public void setdock(Gdl.DockItem _di)
    {
        di = _di;
    }

    public void show()
    {
        print("%s %s %s\n", di.name,
              di.is_closed().to_string(), di.is_iconified().to_string());

        if(di.is_closed() && ! di.is_iconified())
        {
            di.show();
            di.iconify_item();
        }
    }

    public void update(MSP_NAV_STATUS _n)
    {
        if(mt_voice == true)
        {
            if(_n.nav_error != 0 &&  _n.nav_error != n.nav_error)
            {
                var estr = MSP.nav_error(_n.nav_error);
                mt.message(estr);
            }

            if((_n.nav_mode != n.nav_mode) || (_n.wp_number != n.wp_number))
            {
                string nvstr=null;
                switch(_n.nav_mode)
                {
                    case 1:
                        nvstr = "Return to home initiated.";
                        break;
                    case 2:
                        nvstr = "Navigating to home position.";
                        break;
                    case 3:
                        nvstr = "Switch to infinite position hold.";
                        break;
                    case 4:
                        nvstr = "Start timed position hold.";
                        break;
                    case 5:
                        nvstr = "Navigating to waypoint %d.".printf(_n.wp_number);
                        break;
                    case 7:
                        nvstr = "Starting jump for %d".printf(_n.wp_number);
                        break;
                    case 8:
                        nvstr = "Starting to land.";
                        break;
                    case 9:
                        nvstr = "Landing in progress.";
                        break;
                    case 10:
                        nvstr = "Landed. Please disarm.";
                        break;
                }
                if(nvstr != null)
                    mt.message(nvstr);
            }
        }

        n = _n;

        if(!di.is_closed() || Logger.is_logging)
        {
            var gstr = MSP.gps_mode(n.gps_mode);
            var nstr = MSP.nav_state(n.nav_mode);
            var n_action = n.action;
            var n_wpno = n.wp_number;
            var estr = MSP.nav_error(n.nav_error);
            var tbrg = (uint16.from_little_endian(n.target_bearing));
            if (!di.is_closed())
            {
                gps_mode_label.set_label(gstr);
                nav_state_label.set_label(nstr);
                var act = MSP.get_wpname((MSP.Action)n_action);
                nav_action_label.set_label(act);
                nav_wp_label.set_label("%d".printf(n_wpno));
                nav_err_label.set_label(estr);
                nav_tgt_label.set_label("%d".printf(tbrg));
            }
            if (Logger.is_logging)
            {
                Logger.status(n);
            }
        }
    }

    public void set_attitude(MSP_ATTITUDE _atti)
    {
        atti = _atti;
        if(visible || Logger.is_logging)
        {
            double dax;
            double day;
            dax = (double)(int16.from_little_endian(atti.angx))/10.0;
            day = (double)(int16.from_little_endian(atti.angy))/10.0;
            int hdr = (int16.from_little_endian(atti.heading));
            if(hdr < 0)
                hdr += 360;
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

    public void set_altitude(MSP_ALTITUDE _alti)
    {
        alti = _alti;
        if(visible || Logger.is_logging)
        {
            double vario = (int16.from_little_endian(alti.vario))/10.0;
            double estalt = (int32.from_little_endian(alti.estalt))/100.0;
            if(visible)
            {
                var str = "%.2fm / %.1fm/s".printf(estalt, vario);
                nav_altitude_label.set_label(str);
            }
            if(Logger.is_logging)
            {
                Logger.altitude(estalt,vario);
            }
        }
    }

    public void comp_gps(MSP_COMP_GPS _cg)
    {
        cg = _cg;
        if(visible || Logger.is_logging)
        {
            int brg = (int)(int16.from_little_endian(cg.direction));
            if(brg < 0)
                brg += 360;

            if(visible)
            {
                var str = "%dm / %d° / %s".printf(
                    (uint16.from_little_endian(cg.range)),
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
    public void volt_update(string s, int n, float v)
    {
        volts = v;
        Gtk.Allocation a;
        voltlabel.get_allocation(out a);
        var fh1 = a.width/4;
        var fh2 = a.height / 2;
        var fs = (fh1 < fh2) ? fh1 : fh2;
        voltlabel.override_background_color(Gtk.StateFlags.NORMAL, colors[n]);
        voltlabel.set_label("<span font='%d'>%s</span>".printf(fs,s));
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

    public void announce(uint8 mask, bool recip)
    {
        if((mask & SPK.GPS) == SPK.GPS)
        {
            int brg = (int)(int16.from_little_endian(cg.direction));
            if(brg < 0)
                brg += 360;

            if(recip)
                brg = ((brg + 180) % 360);

            mt.message("Range %d, bearing %d.".printf(
                        (uint16.from_little_endian(cg.range)),
                        brg));
        }
        if((mask & SPK.BARO) == SPK.BARO)
        {
            double estalt = (double)(int32.from_little_endian(alti.estalt))/100.0;
            var str = "Altitude %.1f.".printf(estalt);
            str = str_zero(str);
            mt.message(str);
        }

        if((mask & SPK.Volts) == SPK.Volts && volts > 0.0)
        {
            var str = "Voltage %.1f.".printf( volts);
            str = str_zero(str);
            mt.message(str);
        }
    }

    public void logspeak_init (string? voice)
    {
        if(vinit == false)
        {
            vinit = true;
            if(voice == null)
                voice = "default";
            espeak_init(voice);
        }
        mt = new AudioThread();
        mt.start();
        mt_voice=true;
    }

    public void logspeak_close()
    {
        mt_voice=false;
        mt.clear();
        mt.message("");
        mt.thread.join ();
        mt = null;
    }
}

public class AudioThread : Object {
    private AsyncQueue<string> msgs;
    public Thread<int> thread {private set; get;}

    public AudioThread () {
        msgs = new AsyncQueue<string> ();
    }

    public void message(string? s)
    {
        msgs.push(s);
    }

    public void clear()
    {
        while (msgs.try_pop() != null)
            ;
    }

    public void start()
    {
        thread = new Thread<int> ("mwp audio", () => {
                while(true)
                {
                    var s = msgs.pop();
                    if (s == "")
                        break;
                    espeak_say(s);
                }
                return 0;
            });
    }
}

public class NavConfig : GLib.Object
{
    private Gtk.Window window;
    private bool visible;
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
    private MWPlanner _mwp;

    public NavConfig (Gtk.Window parent, Gtk.Builder builder, MWPlanner m)
    {
        _mwp = m;
        window = builder.get_object ("nc_window") as Gtk.Window;
        var button = builder.get_object ("nc_close") as Gtk.Button;
        button.clicked.connect(() => {
                window.hide();
            });

        var apply = builder.get_object ("nc_apply") as Gtk.Button;
        apply.clicked.connect(() => {
                MSP_NAV_CONFIG ncu = {0};
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
                u16 = (uint16)(double.parse(nav_bank_max.get_text())*100);
                ncu.nav_bank_max = u16;
                u16 = (uint16)int.parse(rth_altitude.get_text());
                ncu.rth_altitude = u16;
                ncu.land_speed = (uint8)int.parse(land_speed.get_text());
                u16 = (uint16)int.parse(fence.get_text());
                ncu.fence = u16;
                ncu.crosstrack_gain = _xtrack;
                ncu.max_wp_number = _maxwp;
                _mwp.update_config(ncu);
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

        window.set_transient_for(parent);
        window.destroy.connect (() => {
                window.hide();
                visible = false;
            });
    }

    public void update(MSP_NAV_CONFIG nc)
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

        uint16 u16;
        u16 = uint16.from_little_endian(nc.wp_radius);
        wp_radius.set_text(u16.to_string());
        u16 = uint16.from_little_endian(nc.safe_wp_distance);
        safe_wp_dist.set_text(u16.to_string());
        u16 = uint16.from_little_endian(nc.nav_max_altitude);
        nav_max_alt.set_text(u16.to_string());
        u16 = uint16.from_little_endian(nc.nav_speed_max);
        nav_speed_max.set_text(u16.to_string());
        u16 = uint16.from_little_endian(nc.nav_speed_min);
        nav_speed_min.set_text(u16.to_string());

        _xtrack = nc.crosstrack_gain;
        crosstrack_gain.set_text("%.2f".printf((double)_xtrack/100.0));

        u16 = uint16.from_little_endian(nc.nav_bank_max);
        nav_bank_max.set_text("%.2f".printf((double)u16/100.0));
        u16 = uint16.from_little_endian(nc.rth_altitude);
        rth_altitude.set_text(u16.to_string());
        land_speed.set_text(nc.land_speed.to_string());
        u16 = uint16.from_little_endian(nc.fence);
        fence.set_text(u16.to_string());
        _maxwp = nc.max_wp_number;
        max_wp_no.set_text(_maxwp.to_string());
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

    public double lat {get; private set;}
    public double lon {get; private set;}
    public double cse {get; private set;}
    public double spd {get; private set;}

    public GPSInfo(Gtk.Grid grid)
    {
        var lab = new Gtk.Label("No. Satellites");
        lab.set_alignment(0,0);
        grid.attach(lab, 0, 0, 1, 1);
        nsat_lab = new Gtk.Label("-1");
        grid.attach(nsat_lab, 1, 0, 1, 1);

        lab = new Gtk.Label("Latitude");
        lab.set_alignment(0,0);
        grid.attach(lab, 0, 1, 1, 1);
        lat_lab = new Gtk.Label("--.------");
        lat_lab.set_alignment(0,0);
        grid.attach(lat_lab, 1, 1, 1, 1);

        lab = new Gtk.Label("Longitude");
        lab.set_alignment(0,0);
        grid.attach(lab, 0, 2, 1, 1);
        lon_lab = new Gtk.Label("---.------");
        lon_lab.set_alignment(0,0);
        grid.attach(lon_lab, 1, 2, 1, 1);

        lab = new Gtk.Label("Altitude");
        lab.set_alignment(0,0);
        grid.attach(lab, 0, 3, 1, 1);
        alt_lab = new Gtk.Label("---");
        alt_lab.set_alignment(0,0);
        grid.attach(alt_lab, 1, 3, 1, 1);

        lab = new Gtk.Label("Direction");
        lab.set_alignment(0,0);
        grid.attach(lab, 0, 4, 1, 1);
        dirn_lab = new Gtk.Label("---");
        dirn_lab.set_alignment(0,0);
        grid.attach(dirn_lab, 1, 4, 1, 1);

        lab = new Gtk.Label("Speed");
        lab.set_alignment(0,0);
        grid.attach(lab, 0, 5, 1, 1);
        speed_lab = new Gtk.Label("--.-");
        speed_lab.set_alignment(0,0);
        grid.attach(speed_lab, 1, 5, 1, 1);
    }

    public int update(MSP_RAW_GPS g, bool dms)
    {
        lat = (int32.from_little_endian(g.gps_lat))/10000000.0;
        lon = (int32.from_little_endian(g.gps_lon))/10000000.0;
        spd = (uint16.from_little_endian(g.gps_speed))/100.0;
        cse = (uint16.from_little_endian(g.gps_ground_course))/10.0;

        var nsatstr = "%d (%sfix)".printf(g.gps_numsat,
                                       (g.gps_fix==0) ? "no" : "");
        nsat_lab.set_label(nsatstr);
        alt_lab.set_label("%d m".printf(g.gps_altitude));

        lat_lab.set_label(PosFormat.lat(lat,dms));
        lon_lab.set_label(PosFormat.lon(lon,dms));

        speed_lab.set_label("%.1f m/s".printf(spd));
        dirn_lab.set_label("%.1f °".printf(cse));
        if(Logger.is_logging)
        {
            Logger.raw_gps(lat,lon,cse,spd,
                           g.gps_altitude,
                           g.gps_fix,
                           g.gps_numsat);
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
    }
}
