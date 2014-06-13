
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
    private Settings settings;
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
    public bool scary_warn {get; set; default=true;}
    public bool dms {get; set; default=false;}
    public string? map_sources {get; set; default=null;}
    public uint  speakint {get; set; default=0;}
    public uint  buadrate {get; set; default=57600;}
    public string evoice {get; private set; default=null;}
    public bool recip {get; set; default=false;}
    public bool recip_head {get; set; default=false;}
    public uint  baudrate {get; set; default=57600;}
    public string mediap {get; set;}

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

        } catch {
            stderr.printf("No settings schema\n");
            Posix.exit(-1);
        }
    }

    public void read_settings()
    {
        devices = settings.get_strv ("device-names");
        defmap = settings.get_string ("default-map");
        latitude = settings.get_double("default-latitude");
        longitude = settings.get_double("default-longitude");
        loiter = settings.get_uint("default-loiter");
        altitude = settings.get_uint("default-altitude");
        nav_speed = settings.get_double("default-nav-speed");
        zoom = settings.get_uint("default-zoom");
        compat_vers = settings.get_string ("compat-version");
        scary_warn = settings.get_boolean("show-scary-warning");
        map_sources = settings.get_string ("map-sources");
        dms = settings.get_boolean("display-dms");
        recip = settings.get_boolean("audio-bearing-is-reciprocal");
        recip_head = settings.get_boolean("set_head-is-b0rken");
        speakint = settings.get_uint("speak-interval");
        if(speakint > 0 && speakint < 15)
            speakint = 15;
        evoice = settings.get_string ("espeak-voice");
        baudrate = settings.get_uint("baudrate");
        mediap = settings.get_string ("media-player");
        if(map_sources == "")
            map_sources = null;

        if (devices == null)
            devices = {};
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
