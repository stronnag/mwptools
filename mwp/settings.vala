
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


public class MWPSettings : GLib.Object
{
    public Settings settings {get; private set;}
    private const string sname = "org.mwptools.planner";
    private SettingsSchema schema;
    public double latitude {get; set; default=0.0;}
    public double longitude {get; set; default=0.0;}
    public uint loiter {get; set; default=30;}
    public uint altitude {get; set; default=20;}
    public double nav_speed {get; set; default=2.5;}
    public uint zoom {get; set; default=12;}
    public string? defmap {get; set; default=null;}
    public string[]? devices {get; set; default=null;}
    public string? compat_vers {get; set; default=null;}
    public bool scary_warn {get; set; default=false;}
    public bool dms {get; set; default=false;}
    public string? map_sources {get; set; default=null;}
    public uint  speakint {get; set; default=0;}
    public uint  buadrate {get; set; default=57600;}
    public string evoice {get; private set; default=null;}
    public bool recip {get; set; default=false;}
    public bool recip_head {get; set; default=false;}
    public bool audioarmed {get; set; default=false;}
    public bool logarmed {get; set; default=false;}
    public bool autofollow {get; set; default=false;}
    public uint  baudrate {get; set; default=57600;}
    public string mediap {get; set;}
    public string heartbeat {get; set;}

    public MWPSettings()
    {
        string?[] devs;
        devs=null;
        var uc = Environment.get_user_data_dir();
        uc += "/glib-2.0/schemas/";
        try
        {
            SettingsSchemaSource sss = new SettingsSchemaSource.from_directory (uc, null, false);
            schema = sss.lookup (sname, false);
            if (schema != null)
                settings = new Settings.full (schema, null, null);
            else
                settings =  new Settings (sname);

            settings.changed.connect ((s) => {
                    stderr.printf("changed %s settings\n",s);
                    read_settings(s);
                });
        } catch {
            stderr.printf("No settings schema\n");
            Posix.exit(-1);
        }
    }

    public void read_settings(string? s=null)
    {
        if(s == null || s == "device-names")
        {
            devices = settings.get_strv ("device-names");
            if (devices == null)
                devices = {};
        }
        if(s == null || s == "default-map")
            defmap = settings.get_string ("default-map");
        if(s == null || s == "default-latitude")
            latitude = settings.get_double("default-latitude");
        if(s == null || s == "default-longitude")
            longitude = settings.get_double("default-longitude");
        if(s == null || s == "default-loiter")
            loiter = settings.get_uint("default-loiter");
        if(s == null || s == "default-altitude")
            altitude = settings.get_uint("default-altitude");
        if(s == null || s == "default-nav-speed")
            nav_speed = settings.get_double("default-nav-speed");
        if(s == null || s == "default-zoom")
            zoom = settings.get_uint("default-zoom");
        if(s == null || s == "compat-version")
            compat_vers = settings.get_string ("compat-version");
        if(s == null || s == "map-sources")
        {
            map_sources = settings.get_string ("map-sources");
            if(map_sources == "")
                map_sources = null;
        }
        if(s == null || s == "display-dms")
            dms = settings.get_boolean("display-dms");
        if(s == null || s == "audio-bearing-is-reciprocal")
            recip = settings.get_boolean("audio-bearing-is-reciprocal");
        if(s == null || s == "set-head-is-b0rken")
            recip_head = settings.get_boolean("set-head-is-b0rken");
        if(s == null || s == "audio-on-arm")
            audioarmed = settings.get_boolean("audio-on-arm");
        if(s == null || s == "log-on-arm")
            logarmed = settings.get_boolean("log-on-arm");
        if(s == null || s == "auto-follow")
            autofollow = settings.get_boolean("auto-follow");
        if(s == null || s == "speak-interval")
        {
            speakint = settings.get_uint("speak-interval");
            if(speakint > 0 && speakint < 15)
                speakint = 15;
        }
        if(s == null || s == "espeak-voice")
            evoice = settings.get_string ("espeak-voice");
        if(s == null || s == "baudrate")
            baudrate = settings.get_uint("baudrate");
        if(s == null || s == "media-player")
            mediap = settings.get_string ("media-player");
        if(s == null || s == "heartbeat")
            mediap = settings.get_string ("heartbeat");

    }

    public void save_settings()
    {
        if (settings != null)
        {
            settings.set_strv ("device-names", devices);
            settings.set_string ("default-map", defmap);
            settings.set_double("default-latitude", latitude);
            settings.set_double("default-longitude", longitude);
            settings.set_uint("default-loiter", loiter);
            settings.set_uint("default-altitude", altitude);
            settings.set_double("default-nav-speed", nav_speed);
            settings.set_uint("default-zoom", zoom);
            settings.set_boolean("display-dms",dms);
            settings.set_uint("speak-interval",speakint);
        }
        else
        {
            print("no local settings\n");
        }
    }
}
