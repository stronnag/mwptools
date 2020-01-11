
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
    public bool dump_unknown {get; set; default=false;}
    public bool dms {get; set; default=false;}
    public string? map_sources {get; set; default=null;}
    public uint  speakint {get; set; default=0;}
    public uint  buadrate {get; set; default=57600;}
    public string evoice {get; private set; default=null;}
    public string svoice {get; private set; default=null;}
    public string fvoice {get; private set; default=null;}
    public bool recip {get; set; default=false;}
    public bool recip_head {get; set; default=false;}
    public bool audioarmed {get; set; default=false;}
    public bool centreon {get; set; default=false;}
    public bool logarmed {get; set; default=false;}
    public bool autofollow {get; set; default=true;}
    public uint  baudrate {get; set; default=57600;}
    public string mediap {get; private set;}
    public string heartbeat {get; private set;}
    public string atstart {get; private set;}
    public string atexit {get; private set;}
    public string? fctype {get; private set;}
    public string? vlevels {get; private set;}
    public bool checkswitches {get; set; default=false;}
    public uint polltimeout {get; set; default=900;}
    public string deflayout {get; private set; }
    public uint p_distance {get; set; default=0;}
    public uint p_speed {get; set; default=0;}
    public string mavph {get; set; default=null;}
    public string mavrth {get; set; default=null;}
    public double window_p {get; set; default=72;}
    public int fontfact {get; set; default = 12;}
    public int ahsize {get; set; default = 32;}
    public uint gpsintvl {get; set; default = 2000;}
    public string uilang {get; private set; default=null;}
    public string led {get; private set; default=null;}
    public string rcolstr {get; private set; default=null;}
    public bool tote_floating {get; set; default=false;}
    public bool rth_autoland {get; set; default=false;}
    public string missionpath {get; private set; default=null;}
    public string logpath {get; private set; default=null;}
    public string logsavepath {get; private set; default=null;}
    public double max_home_delta {get; set; default=2.5;}
    public bool ignore_nm {get; set; default=false;}
    public bool ah_inv_roll {get; set; default=false;}
    public string speech_api {get; private set; default=null;}
    public uint stats_timeout {get; set; default=30;}
    public bool auto_restore_mission {get; set; default=false;}
    public int forward {get; set; default=0;}
    public bool need_telemetry {get; set; default=false;}
    public string wp_text {get; set; default="Sans 144/#ff000080";}
    public string wp_spotlight {get; set; default="#ffffff60";}
    public uint flash_warn { get; set; default=0; }
    public bool auto_wp_edit {get; set; default=true;}
    public bool use_legacy_centre_on {get; set; default=false;}
    public bool horizontal_dbox {get; set; default=false;}
    public string mission_file_type {get; set; default="m";}
    public uint osd_mode {get; set; default=3;}
    public double wp_dist_fontsize {get; set; default=56;}
    public bool adjust_tz {get; set; default=true;}
    public string blackbox_decode {get; set; default="blackbox_decode";}
    public string geouser {get; set; default=null;}
    public string zone_detect {get; set; default=null;}
    public string mag_sanity {get; set; default=null;}
    public bool say_bearing {get; set; default=true;}
    public bool pos_is_centre {get; set; default=true;}
    public double deltaspeed {get; set; default=0.0;}
    public int smartport_fuel  {get; set; default = 0;}
    public int speak_amps {get; set; default=0;}
    public bool arming_speak {get; set; default=false;}
    public uint max_radar { get; set; default=4; }
    public string kmlpath {get; private set; default=null;}
    public bool fixedfont {get; set; default=true;}

//    public string radar_device {get; set; default=null;}

    public signal void settings_update (string s);

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
        } catch {}

        if (schema != null)
            settings = new Settings.full (schema, null, null);
        else
            settings =  new Settings (sname);

        settings.changed.connect ((s) => {
                read_settings(s);
                settings_update(s);
            });
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
        if(s == null || s == "dump-unknown")
            dump_unknown = settings.get_boolean("dump-unknown");
        if(s == null || s == "display-dms")
            dms = settings.get_boolean("display-dms");
        if(s == null || s == "audio-bearing-is-reciprocal")
            recip = settings.get_boolean("audio-bearing-is-reciprocal");
        if(s == null || s == "set-head-is-b0rken")
            recip_head = settings.get_boolean("set-head-is-b0rken");
        if(s == null || s == "audio-on-arm")
            audioarmed = settings.get_boolean("audio-on-arm");
        if(s == null || s == "centre-on")
            centreon = settings.get_boolean("centre-on");
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
        if(s == null || s == "speechd-voice")
            svoice = settings.get_string ("speechd-voice");
        if(s == null || s == "flite-voice-file")
            fvoice = settings.get_string ("flite-voice-file");
        if(s == null || s == "baudrate")
            baudrate = settings.get_uint("baudrate");
        if(s == null || s == "media-player")
            mediap = settings.get_string ("media-player");
        if(s == null || s == "heartbeat")
            heartbeat = settings.get_string ("heartbeat");
        if(s == null || s == "atstart")
            atstart = settings.get_string ("atstart");
        if(s == null || s == "atexit")
            atexit = settings.get_string ("atexit");
        if(s == null || s == "fctype")
            fctype = settings.get_string ("fctype");
        if(s == null || s == "vlevels")
            vlevels = settings.get_string ("vlevels");
        if(s == null || s == "checkswitches")
            checkswitches = settings.get_boolean("checkswitches");
        if(s == null || s == "poll-timeout")
            polltimeout = settings.get_uint("poll-timeout");

        if(s == null || s == "default-layout")
        {
            deflayout = settings.get_string("default-layout");
            if(deflayout == "")
                deflayout = null;
        }

        if(s == null || s == "display-distance")
        {
            p_distance = settings.get_uint("display-distance");
            if(p_distance > 2)
                p_distance = 0;
        }

        if(s == null || s == "display-speed")
        {
            p_speed = settings.get_uint("display-speed");
            if(p_speed > 3)
                p_distance = 0;
        }

        if(s == null || s == "mavph")
            mavph = settings.get_string ("mavph");
        if(s == null || s == "mavrth")
            mavrth = settings.get_string ("mavrth");
        if(s == null || s == "pwdw-p")
            window_p = settings.get_double("pwdw-p");
        if(s == null || s == "font-fv")
            fontfact = settings.get_int("font-fv");
        if(s == null || s == "ah-size")
            ahsize = settings.get_int("ah-size");
        if(s == null || s == "uilang")
            uilang = settings.get_string ("uilang");
        if(s == null || s == "gpsintvl")
            gpsintvl = settings.get_uint("gpsintvl");
        if(s == null || s == "led")
            led = settings.get_string ("led");
        if(s == null || s == "rings-colour")
            rcolstr = settings.get_string ("rings-colour");
        if(s == null || s == "tote-float-p")
            tote_floating = settings.get_boolean ("tote-float-p");
        if(s == null || s == "rth-autoland")
            rth_autoland  = settings.get_boolean ("rth-autoland");

        if(s == null || s == "ignore-nm")
            ignore_nm = settings.get_boolean ("ignore-nm");

        if(s == null || s == "ah-invert-roll")
            ah_inv_roll = settings.get_boolean ("ah-invert-roll");

        if(s == null || s == "mission-path")
        {
            missionpath = settings.get_string ("mission-path");
            if(missionpath == "")
                missionpath = null;
        }
        if(s == null || s == "kml-path")
        {
            kmlpath = settings.get_string ("kml-path");
            if(kmlpath == "")
                kmlpath = null;
        }

        if(s == null || s == "log-path")
        {
            logpath = settings.get_string ("log-path");
            if(logpath == "")
                logpath = null;
        }

        if(s == null || s == "log-save_path")
        {
            logsavepath = settings.get_string ("log-save-path");
            if(logsavepath == "")
                logsavepath = null;
        }

        if(s == null || s == "max-home-delta")
            max_home_delta = settings.get_double ("max-home-delta");

        if(s == null || s == "speech-api")
        {
            speech_api = settings.get_string ("speech-api");
            if(speech_api == "")
                speech_api = null;
        }

        if(s == null || s == "stats-timeout")
            stats_timeout = settings.get_uint("stats-timeout");

        if(s == null || s == "auto-restore-mission")
            auto_restore_mission = settings.get_boolean("auto-restore-mission");

        if(s == null || s == "require-telemetry")
            need_telemetry = settings.get_boolean("require-telemetry");

        if(s == null || s == "forward")
            forward = settings.get_enum("forward");

        if(s == null || s == "wp-text-style")
            wp_text = settings.get_string ("wp-text-style");

        if(s == null || s == "wp-spotlight")
            wp_spotlight = settings.get_string ("wp-spotlight");

        if(s == null || s == "flash-warn")
            flash_warn = settings.get_uint("flash-warn");

        if(s == null || s == "auto-wp-edit")
            auto_wp_edit = settings.get_boolean("auto-wp-edit");

        if(s == null || s == "use-legacy-centre-on")
            use_legacy_centre_on = settings.get_boolean("use-legacy-centre-on");

        if(s == null || s == "dbox-is-horizontal")
            horizontal_dbox = settings.get_boolean("dbox-is-horizontal");

        if(s == null || s == "mission-file-type")
            mission_file_type = settings.get_string ("mission-file-type");

        if(s == null || s == "osd-mode")
            osd_mode = settings.get_uint("osd-mode");

        if(s == null || s == "wp-dist-size")
            wp_dist_fontsize = settings.get_double("wp-dist-size");

        if(s == null || s == "adjust-tz")
            adjust_tz = settings.get_boolean("adjust-tz");

        if(s == null || s == "blackbox-decode")
            blackbox_decode = settings.get_string ("blackbox-decode");

        if(s == null || s == "geouser")
        {
            geouser = settings.get_string ("geouser");
            if(geouser == "")
                geouser = null;
        }
        if(s == null || s == "zone-detect")
        {
            zone_detect = settings.get_string ("zone-detect");
            if(zone_detect == "")
                zone_detect = null;
        }

        if(s == null || s == "mag-sanity")
        {
            mag_sanity = settings.get_string("mag-sanity");
            if (mag_sanity == "")
                mag_sanity = null;
        }

        if(s == null || s == "say-bearing")
            say_bearing = settings.get_boolean("say-bearing");

        if(s == null || s == "pos-is-centre")
            pos_is_centre = settings.get_boolean("pos-is-centre");
        if(s == null || s == "delta-minspeed")
            deltaspeed = settings.get_double("delta-minspeed");

        if(s == null || s == "smartport-fuel-unit")
            smartport_fuel = settings.get_enum("smartport-fuel-unit");

        if(s == null || s == "speak-amps")
            speak_amps = settings.get_enum("speak-amps");

        if(s == null || s == "max-radar-slots")
            max_radar =  settings.get_uint("max-radar-slots");

        if(s == null || s == "arming-speak")
            arming_speak  = settings.get_boolean("arming-speak");

        if(s == null || s == "fixedfont")
            fixedfont = settings.get_boolean ("fixedfont");

            /** CLI for now
        if(s == null || s == "radar-device")
        {
            radar_device = settings.get_string("radar-device");
            if (radar_device == "")
                radar_device = null;
        }
            ***/
    }

    public void save_pane()
    {
        if (settings != null)
            settings.set_double("pwdw-p", window_p);
    }

    public void save_floating(bool val)
    {
        if (settings != null)
            settings.set_boolean("tote-float-p", val);
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
            settings.set_uint("display-distance", p_distance);
            settings.set_uint("display-speed", p_speed);
        }
        else
        {
            print("no local settings\n");
        }
    }
}
