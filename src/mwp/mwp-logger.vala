/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

namespace Logger {
    public bool is_logging;
    internal Json.Generator gen;
    internal FileStream os;
    internal double dtime;
    public int duration;

    internal bool verify_save_path(string path) {
        bool res;
        var f = File.new_for_path(path);
        if((res = f.query_exists()) == false) {
            try {
                res = f.make_directory_with_parents();
            } catch {};
        }
        return res;
    }

    public void start(string? save_path, string? _vname) {
		var dt = new DateTime.now_local ();
		string vname = _vname;
		if (vname == null || vname.length == 0) {
			vname="unknown";
		} else {
			vname = vname.replace(" ", "_");
		}
		var ts = dt.format("%F_%H%M%S");
		var fn  = "mwp-%s-%s.log".printf(vname, ts);
        if(save_path != null && verify_save_path(save_path)) {
            fn = GLib.Path.build_filename(save_path, fn);
        }

        os = FileStream.open(fn, "w");
        if(os != null) {
            MWPLog.message ("Logging to %s\n", fn);
            is_logging = true;
            log_time();
        } else {
            MWPLog.message ("Logger can't open %s\n", fn);
            is_logging = false;
            return;
        }

        gen = new Json.Generator ();
        var builder = init("environment");
        builder.set_member_name ("host");
        builder.add_string_value (get_host_info(null));
        builder.set_member_name ("mwpinfo");
        builder.add_string_value (MwpVers.get_build());
        builder.set_member_name ("mwpid");
        builder.add_string_value (MwpVers.get_id());
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }
	/*
	public void rawdata(uint16 cmd, uint8[]raw, uint len) {
		var builder = init("rawdata");
		builder.set_member_name ("mid");
		builder.add_int_value(cmd);
		builder.set_member_name ("msg");
		var sb = new StringBuilder();
		for (var j = 0; j < len; j++) {
			sb.append_printf("%02x", raw[j]);
        }
		builder.add_string_value(sb.str);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
	}
	*/
	public void logstring(string id, string msg) {
		var builder = init("text");
		builder.set_member_name ("id");
		builder.add_string_value(id);
		builder.set_member_name ("content");
		builder.add_string_value(msg);
        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
	}

	public void fcinfo(string? title, VersInfo vi,uint32 capability,
                              uint8 profile, string? boxnames = null,
                              string? vname = null, string? device = null,
							  uint8[] boxids = {})  {
        gen = new Json.Generator ();
        var builder = init("init");
        if(title != null) {
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
        builder.set_member_name ("fcname");
        builder.add_string_value (vi.name);

        if(vname != null) {
            builder.set_member_name ("vname");
            builder.add_string_value (vname);
        }

        if(boxnames != null) {
            builder.set_member_name ("boxnames");
            builder.add_string_value (boxnames);
        }

		if (boxids.length != 0) {
            builder.set_member_name ("boxids");
			builder.begin_array();
			for(var i = 0; i < boxids.length; i++) {
				builder.add_int_value(boxids[i]);
			}
			builder.end_array();
		}

        if(vi.fc_var != null) {
            builder.set_member_name ("fc_var");
            builder.add_string_value (vi.fc_var);
            builder.set_member_name ("fc_verx");
            builder.add_string_value ("%06x".printf(vi.fc_vers));
            builder.set_member_name ("fc_vers");
            builder.add_int_value (vi.fc_vers);
            builder.set_member_name ("fc_vers_str");
            uchar vs[4];
            SEDE.serialise_u32(vs, vi.fc_vers);
            builder.add_string_value ("%d.%d.%d".printf(vs[2],vs[1],vs[0]));
            if(vi.fc_git != null) {
                builder.set_member_name ("git_info");
                builder.add_string_value (vi.fc_git);
            }
        }

        if (device != null) {
            builder.set_member_name ("source");
            builder.add_string_value (device);
        }

        builder.end_object ();
        Json.Node root = builder.get_root ();
        gen.set_root (root);
        write_stream();
    }

    public string get_host_info(out string os) {
		os="";
#if UNIX
        string r=null;
        var dis = FileStream.open("/etc/os-release","r");
        if(dis != null) {
            string line;
            while ((line = dis.read_line ()) != null) {
                var parts = line.split("=");
                if (parts.length == 2)
                    if (parts[0] == "PRETTY_NAME")
                        r = parts[1].replace("\"","");
            }
        }
        var u = Posix.utsname();
        var sb = new StringBuilder();
        if (r != null) {
            sb.append_c('"');
            sb.append(r);
            sb.append_c('"');
            sb.append(" on ");
        }
        sb.append(u.nodename);
        sb.append(" running ");
        os = u.sysname;
        sb.append(u.sysname);
        sb.append_c(' ');
        sb.append(u.release);
        sb.append_c(' ');
        sb.append(u.machine);
        return sb.str;
#else
		return "on msys2 (probably, good luck)";
#endif
    }

    internal  void write_stream() {
        os.puts(gen.to_data (null));
        os.putc('\n');
    }

    public void stop() {
        is_logging = false;
        os.flush();
    }

    public void log_time() {
        var t = Posix.timeval();
        t.get_time_of_day();
        dtime = t.tv_sec + t.tv_usec/1000000.0;
    }

    internal Json.Builder init(string typ) {
        Json.Builder builder = new Json.Builder ();
        builder.begin_object ();
		builder.set_member_name ("type");
        builder.add_string_value (typ);
		builder.set_member_name ("utime");
        builder.add_double_value (dtime);
        return builder;
    }

    public void armed(bool armed, time_t _duration, uint64 flags,
                             uint32 sensor, bool telem=false) {
        duration = (int)_duration;
        var builder = init("armed");
        builder.set_member_name("armed");
        builder.add_boolean_value(armed);
        if(duration > -1) {
            builder.set_member_name("duration");
            builder.add_int_value(_duration);
        }
        builder.set_member_name("flags");
        builder.add_int_value((int64)flags);
        builder.set_member_name("sensors");
        builder.add_int_value(sensor);
        builder.set_member_name("telem");
        builder.add_boolean_value(telem);
        builder.end_object ();
        Json.Node root = builder.get_root ();
		gen.set_root (root);
        write_stream();
    }

    public void ltm_sframe(LTM_SFRAME s, string? status) {
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

    public void ltm_oframe(LTM_OFRAME o) {
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

    public void ltm_xframe(LTM_XFRAME x) {
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

    public void gpssvinfo(uint8 []raw) {
        var builder = init("gpssvinfo");
        builder.set_member_name ("no_sats");
        builder.add_int_value(raw[0]);
        builder.set_member_name("satellites");
        builder.begin_array ();
        var n = 1;
        for(var i = 0; i < raw[0]; i++) {
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

    public void analog(MSP_ANALOG a) {
        var builder = init("analog");
        builder.set_member_name ("voltage");
        builder.add_double_value(((double)a.vbat/10.0));
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

    public void analog2(MSP_ANALOG2 a) {
        var builder = init("analog2");
        builder.set_member_name ("voltage");
        builder.add_double_value(((double)a.vbat/100.0));
        builder.set_member_name ("power");
        builder.add_int_value(a.mahdraw);
        builder.set_member_name ("rssi");
        builder.add_int_value(a.rssi);
        builder.set_member_name ("amps");
        builder.add_int_value(a.amps);
        builder.end_object ();
        Json.Node root = builder.get_root ();
		gen.set_root (root);
        write_stream();
    }

    public void comp_gps(int brg, uint16 range, uint8 update) {
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

    public void raw_gps(double lat, double lon, double cse, double spd,
                               int16 alt, uint8 fix, uint8 numsat, uint16 hdop) {
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

    public void attitude(double dax, double day, int hdr) {
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

    public void altitude(double estalt, double vario) {
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

    public void status(MSP_NAV_STATUS n) {
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

    public void wp_poll(MSP_WP w) {
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

    public void mav_heartbeat (Mav.MAVLINK_HEARTBEAT m) {
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

    public void mav_sys_status (Mav.MAVLINK_SYS_STATUS m) {
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

    public void mav_gps_raw_int (Mav.MAVLINK_GPS_RAW_INT m) {
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

    public void mav_attitude (Mav.MAVLINK_ATTITUDE m) {
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

    public void mav_rc_channels (Mav.MAVLINK_RC_CHANNELS m) {
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

    public void mav_gps_global_origin (Mav.MAVLINK_GPS_GLOBAL_ORIGIN m) {
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

    public void mav_vfr_hud (Mav.MAVLINK_VFR_HUD m) {
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
