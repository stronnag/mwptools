
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
//using Json;

public class Logger : GLib.Object
{
    public static bool is_logging { get; private set; }
    private static Json.Generator gen;
    private static FileStream os;
    private static double dtime;
    public static int duration { get; private set; }

    private static bool verify_save_path(string path)
    {
        bool res;
        var f = File.new_for_path(path);
        if((res = f.query_exists()) == false)
        {
            try {
                res = f.make_directory_with_parents();
            } catch {};
        }
        return res;
    }

    public static void start(string? save_path = null)
    {
        time_t currtime;
        time_t(out currtime);
        var fn  = "mwp_%s.log".printf(Time.local(currtime).format("%F_%H%M%S"));
        if(save_path != null && verify_save_path(save_path))
        {
            fn = GLib.Path.build_filename(save_path, fn);
        }

        os = FileStream.open(fn, "w");
        if(os != null)
        {
            MWPLog.message ("Logging to %s\n", fn);
            is_logging = true;
            log_time();
        }
        else
        {
            MWPLog.message ("Logger can't open %s\n", fn);
            is_logging = false;
            return;
        }

        gen = new Json.Generator ();
        var builder = init("environment");
        builder.set_member_name ("host");
        builder.add_string_value (get_host_info());
        builder.set_member_name ("mwpinfo");
        builder.add_string_value (mwpvers);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    public static void fcinfo(string? title, VersInfo vi,uint32 capability,
                              uint8 profile, string? boxnames = null)
    {
        gen = new Json.Generator ();
        var builder = init("init");
        if(title != null)
        {
            builder.set_member_name ("mission");
            builder.add_string_value (title);
        }

        builder.set_member_name ("mwvers");
        builder.add_int_value (vi.mvers);
        builder.set_member_name ("mrtype");
        builder.add_int_value (vi.mrtype);
        builder.set_member_name ("capability");
        builder.add_int_value (capability);
        builder.set_member_name ("fctype");
        builder.add_int_value (vi.fctype);
        builder.set_member_name ("profile");
        builder.add_int_value (profile);
        builder.set_member_name ("fcboard");
        builder.add_string_value (vi.board);

        if(boxnames != null)
        {
            builder.set_member_name ("boxnames");
            builder.add_string_value (boxnames);
        }

        if(vi.fc_var != null)
        {
            builder.set_member_name ("fc_var");
            builder.add_string_value (vi.fc_var);
            builder.set_member_name ("fc_vers");
            builder.add_int_value (vi.fc_vers);
            builder.set_member_name ("fc_vers_str");
            uchar *vs;
            vs = (uchar*)&vi.fc_vers;
            builder.add_string_value ("%d.%d.%d".printf(vs[0],vs[1],vs[2]));
            if(vi.fc_git != null)
            {
                builder.set_member_name ("git_info");
                builder.add_string_value (vi.fc_git);
            }
        }
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    private static string get_host_info()
    {
        string r=null;
        var dis = FileStream.open("/etc/os-release","r");
        if(dis != null)
        {
            string line;
            while ((line = dis.read_line ()) != null)
            {
                var parts = line.split("=");
                if (parts.length == 2)
                    if (parts[0] == "PRETTY_NAME")
                        r = parts[1].replace("\"","");
            }
        }
        var u = Posix.utsname();
        var sb = new StringBuilder();
        if (r != null)
        {
            sb.append(r);
            sb.append(" ");
        }
        sb.append(u.nodename);
        sb.append(" ");
        sb.append(u.sysname);
        sb.append(" ");
        sb.append(u.release);
        sb.append(" ");
        sb.append(u.machine);
        return sb.str;
    }

    private static void write_stream()
    {
        os.puts(gen.to_data (null));
        os.putc('\n');
    }

    public static void stop()
    {
        is_logging = false;
        os.flush();
    }

    public static void log_time()
    {
        var t = Posix.timeval();
        t.get_time_of_day();
        dtime = t.tv_sec + t.tv_usec/1000000.0;
    }

    private static Json.Builder init(string typ)
    {
        Json.Builder builder = new Json.Builder ();
        builder.begin_object ();
	builder.set_member_name ("type");
        builder.add_string_value (typ);
	builder.set_member_name ("utime");
        builder.add_double_value (dtime);
        return builder;
    }

    public static void radio(MSP_RADIO r)
    {
        var builder = init("radio");
        builder.set_member_name("rxerrors");
        builder.add_int_value(r.rxerrors);
        builder.set_member_name("fixed_errors");
        builder.add_int_value(r.fixed_errors);
        builder.set_member_name("localrssi");
        builder.add_int_value(r.localrssi);
        builder.set_member_name("remrssi");
        builder.add_int_value(r.remrssi);
        builder.set_member_name("txbuf");
        builder.add_int_value(r.txbuf);
        builder.set_member_name("noise");
        builder.add_int_value(r.noise);
        builder.set_member_name("remnoise");
        builder.add_int_value(r.remnoise);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void armed(bool armed, time_t _duration, uint32 flags,
                             uint32 sensor, bool telem=false)
    {
        duration = (int)_duration;
        var builder = init("armed");
        builder.set_member_name("armed");
        builder.add_boolean_value(armed);
        if(duration > -1)
        {
            builder.set_member_name("duration");
            builder.add_int_value(_duration);
        }
        builder.set_member_name("flags");
        builder.add_int_value(flags);
        builder.set_member_name("sensors");
        builder.add_int_value(sensor);
        builder.set_member_name("telem");
        builder.add_boolean_value(telem);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void ltm_sframe(LTM_SFRAME s, string? status)
    {
        var builder = init("ltm_raw_sframe");
        builder.set_member_name("vbat");
        builder.add_int_value(s.vbat);
        builder.set_member_name("vcurr");
        builder.add_int_value(s.vcurr);
        builder.set_member_name("rssi");
        builder.add_int_value(s.rssi);
        builder.set_member_name("airspeed");
        builder.add_int_value(s.airspeed);
        builder.set_member_name("flags");
        builder.add_int_value(s.flags);
        builder.set_member_name("status");
        builder.add_string_value(status);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void ltm_oframe(LTM_OFRAME o)
    {
        var builder = init("ltm_raw_oframe");
        builder.set_member_name ("lat");
        builder.add_int_value(o.lat);
        builder.set_member_name ("lon");
        builder.add_int_value(o.lon);
        builder.set_member_name ("fix");
        builder.add_int_value(o.fix);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void ltm_xframe(LTM_XFRAME x)
    {
        var builder = init("ltm_xframe");
        builder.set_member_name ("hdop");
        builder.add_int_value(x.hdop);
        builder.set_member_name ("sensorok");
        builder.add_int_value(x.sensorok);
        builder.set_member_name ("count");
        builder.add_int_value(x.ltm_x_count);
        builder.set_member_name ("reason");
        builder.add_int_value(x.disarm_reason);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void gpssvinfo(uint8 []raw)
    {
        var builder = init("gpssvinfo");
        builder.set_member_name ("no_sats");
        builder.add_int_value(raw[0]);
        builder.set_member_name("satellites");
        builder.begin_array ();
        var n = 1;
        for(var i = 0; i < raw[0]; i++)
        {
            builder.begin_object ();
            builder.set_member_name ("channel");
            builder.add_int_value(raw[n++]);
            builder.set_member_name ("svid");
            builder.add_int_value(raw[n++]);
            builder.set_member_name ("quality");
            builder.add_int_value(raw[n++]);
            builder.set_member_name ("cno");
            builder.add_int_value(raw[n++]);
            builder.end_object();
        }
        builder.end_array();
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void analog(MSP_ANALOG a)
    {
        var builder = init("analog");
        builder.set_member_name ("voltage");
        builder.add_double_value(((double)a.vbat)/10.0);
        builder.set_member_name ("power");
        builder.add_int_value(a.powermetersum);
        builder.set_member_name ("rssi");
        builder.add_int_value(a.rssi);
        builder.set_member_name ("amps");
        builder.add_int_value(a.amps);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void comp_gps(int brg, uint16 range, uint8 update)
    {
	var builder = init ("comp_gps");
        builder.set_member_name ("bearing");
        builder.add_int_value(brg);
        builder.set_member_name ("range");
        builder.add_int_value(range);
        builder.set_member_name ("update");
        builder.add_int_value(update);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void raw_gps(double lat, double lon, double cse, double spd,
                               int16 alt, uint8 fix, uint8 numsat, uint16 hdop)
    {
        var builder = init ("raw_gps");
        builder.set_member_name ("lat");
        builder.add_double_value(lat);
        builder.set_member_name ("lon");
        builder.add_double_value(lon);
        builder.set_member_name ("cse");
        builder.add_double_value(cse);
        builder.set_member_name ("spd");
        builder.add_double_value(spd);
        builder.set_member_name ("alt");
        builder.add_int_value(alt);
        builder.set_member_name ("fix");
        builder.add_int_value(fix);
        builder.set_member_name ("numsat");
        builder.add_int_value(numsat);
        builder.set_member_name ("hdop");
        builder.add_int_value(hdop);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
     }

    public static void attitude(double dax, double day, int hdr)
    {
        var builder = init ("attitude");
        builder.set_member_name ("angx");
        builder.add_double_value(dax);
        builder.set_member_name ("angy");
        builder.add_double_value(day);
        builder.set_member_name ("heading");
        builder.add_int_value(hdr);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void altitude(double estalt, double vario)
    {
        var builder = init ("altitude");
        builder.set_member_name ("estalt");
        builder.add_double_value(estalt);
        builder.set_member_name ("vario");
        builder.add_double_value(vario);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void status(MSP_NAV_STATUS n)
    {
        var builder = init ("status");
        builder.set_member_name ("gps_mode");
        builder.add_int_value(n.gps_mode);
        builder.set_member_name ("nav_mode");
        builder.add_int_value(n.nav_mode);
        builder.set_member_name ("action");
        builder.add_int_value(n.action);
        builder.set_member_name ("wp_number");
        builder.add_int_value(n.wp_number);
        builder.set_member_name ("nav_error");
        builder.add_int_value(n.nav_error);
        builder.set_member_name ("target_bearing");
        builder.add_int_value(n.target_bearing);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void wp_poll(MSP_WP w)
    {
        var builder = init ("wp_poll");
        builder.set_member_name ("wp_no");
        builder.add_int_value(w.wp_no);
        builder.set_member_name ("wp_lat");
        builder.add_double_value(w.lat/10000000.0);
        builder.set_member_name ("wp_lon");
        builder.add_double_value(w.lon/10000000.0);
        builder.set_member_name ("wp_alt");
        builder.add_double_value(w.altitude/100.0);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        write_stream();
    }

    public static void mav_heartbeat (Mav.MAVLINK_HEARTBEAT m)
    {
        var builder = init ("mavlink_heartbeat");
        builder.set_member_name ("custom_mode");
        builder.add_int_value(m.custom_mode);
        builder.set_member_name ("mavtype");
        builder.add_int_value(m.type);
        builder.set_member_name ("autopilot");
        builder.add_int_value(m.autopilot);
        builder.set_member_name ("base_mode");
        builder.add_int_value(m.base_mode);
        builder.set_member_name ("system_status");
        builder.add_int_value(m.system_status);
        builder.set_member_name ("mavlink_version");
        builder.add_int_value(m.mavlink_version);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    public static void mav_sys_status (Mav.MAVLINK_SYS_STATUS m)
    {
        var builder = init ("mavlink_sys_status");
        builder.set_member_name ("onboard_control_sensors_present");
        builder.add_int_value(m.onboard_control_sensors_present);
        builder.set_member_name ("onboard_control_sensors_enabled");
        builder.add_int_value(m.onboard_control_sensors_enabled);
        builder.set_member_name ("onboard_control_sensors_health");
        builder.add_int_value(m.onboard_control_sensors_health);
        builder.set_member_name ("load");
        builder.add_int_value(m.load);
        builder.set_member_name ("voltage_battery");
        builder.add_int_value(m.voltage_battery);
        builder.set_member_name ("current_battery");
        builder.add_int_value(m.current_battery);
        builder.set_member_name ("drop_rate_comm");
        builder.add_int_value(m.drop_rate_comm);
        builder.set_member_name ("errors_comm");
        builder.add_int_value(m.errors_comm);
        builder.set_member_name ("errors_count1");
        builder.add_int_value(m.errors_count1);
        builder.set_member_name ("errors_count2");
        builder.add_int_value(m.errors_count2);
        builder.set_member_name ("errors_count3");
        builder.add_int_value(m.errors_count3);
        builder.set_member_name ("errors_count4");
        builder.add_int_value(m.errors_count4);
        builder.set_member_name ("battery_remaining");
        builder.add_int_value(m.battery_remaining);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    public static void mav_gps_raw_int (Mav.MAVLINK_GPS_RAW_INT m)
    {
        var builder = init ("mavlink_gps_raw_int");
        builder.set_member_name ("time_usec");
        builder.add_int_value((int64)m.time_usec);
        builder.set_member_name ("lat");
        builder.add_int_value(m.lat);
        builder.set_member_name ("lon");
        builder.add_int_value(m.lon);
        builder.set_member_name ("alt");
        builder.add_int_value(m.alt);
        builder.set_member_name ("eph");
        builder.add_int_value(m.eph);
        builder.set_member_name ("epv");
        builder.add_int_value(m.epv);
        builder.set_member_name ("vel");
        builder.add_int_value(m.vel);
        builder.set_member_name ("cog");
        builder.add_int_value(m.cog);
        builder.set_member_name ("fix_type");
        builder.add_int_value(m.fix_type);
        builder.set_member_name ("satellites_visible");
        builder.add_int_value(m.satellites_visible);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    public static void mav_attitude (Mav.MAVLINK_ATTITUDE m)
    {
        var builder = init ("mavlink_attitude");
        builder.set_member_name ("time_boot_ms");
        builder.add_int_value(m.time_boot_ms);
        builder.set_member_name ("roll");
        builder.add_double_value(m.roll);
        builder.set_member_name ("pitch");
        builder.add_double_value(m.pitch);
        builder.set_member_name ("yaw");
        builder.add_double_value(m.yaw);
        builder.set_member_name ("rollspeed");
        builder.add_double_value(m.rollspeed);
        builder.set_member_name ("pitchspeed");
        builder.add_double_value(m.pitchspeed);
        builder.set_member_name ("yawspeed");
        builder.add_double_value(m.yawspeed);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    public static void mav_rc_channels (Mav.MAVLINK_RC_CHANNELS m)
    {
        var builder = init ("mavlink_rc_channels");
        builder.set_member_name ("time_boot_ms");
        builder.add_int_value(m.time_boot_ms);
        builder.set_member_name ("chan1_raw");
        builder.add_int_value(m.chan1_raw);
        builder.set_member_name ("chan2_raw");
        builder.add_int_value(m.chan2_raw);
        builder.set_member_name ("chan3_raw");
        builder.add_int_value(m.chan3_raw);
        builder.set_member_name ("chan4_raw");
        builder.add_int_value(m.chan4_raw);
        builder.set_member_name ("chan5_raw");
        builder.add_int_value(m.chan5_raw);
        builder.set_member_name ("chan6_raw");
        builder.add_int_value(m.chan6_raw);
        builder.set_member_name ("chan7_raw");
        builder.add_int_value(m.chan7_raw);
        builder.set_member_name ("chan8_raw");
        builder.add_int_value(m.chan8_raw);
        builder.set_member_name ("port");
        builder.add_int_value(m.port);
        builder.set_member_name ("rssi");
        builder.add_int_value(m.rssi);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    public static void mav_gps_global_origin (Mav.MAVLINK_GPS_GLOBAL_ORIGIN m)
    {
        var builder = init ("mavlink_gps_global_origin");
        builder.set_member_name ("latitude");
        builder.add_int_value(m.latitude);
        builder.set_member_name ("longitude");
        builder.add_int_value(m.longitude);
        builder.set_member_name ("altitude");
        builder.add_int_value(m.altitude);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    public static void mav_vfr_hud (Mav.MAVLINK_VFR_HUD m)
    {
        var builder = init ("mavlink_vfr_hud");
        builder.set_member_name ("airspeed");
        builder.add_double_value(m.airspeed);
        builder.set_member_name ("groundspeed");
        builder.add_double_value(m.groundspeed);
        builder.set_member_name ("alt");
        builder.add_double_value(m.alt);
        builder.set_member_name ("climb");
        builder.add_double_value(m.climb);
        builder.set_member_name ("heading");
        builder.add_int_value(m.heading);
        builder.set_member_name ("throttle");
        builder.add_int_value(m.throttle);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }
}
