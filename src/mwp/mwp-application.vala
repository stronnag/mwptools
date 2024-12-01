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

namespace Mwp {
	public const string MWPID="org.stronnag.mwp";
	public static string? user_args;

	/* Options parsing */
    private string mission;
    private string kmlfile;
    private string rfile = null;
    private string bfile = null;
	private string clifile = null;

	private string serial;
    private bool mkcon = false;
    private bool autocon;
	private bool zznopoll = false; // Absoluely NOPOLL from user!
    private bool no_trail = false;
    public bool rawlog = false;
    private bool set_fs;
    private bool no_max = false;
    private bool force_mag = false;
    private bool force_nc = false;
    private int dmrtype=0;
    private bool force4 = false;
    private bool chome = false;
    public DEBUG_FLAGS debug_flags = 0;
    private string llstr=null;
    private string rebasestr=null;
    private int stack_size = 0;
    private int mod_points = 0;
    private string rrstr;
    private string? exvox = null;
    private bool asroot = false;
	private string forward_device = null;
    private string[]? radar_device = null;
    private bool relaxed = false;
    private bool ready;
	private bool xnopoll;
	private bool nopoll;
	private string otxfile = null;
    private bool offline = false;
	private string sh_load = null;
	private string gz_load = null;
	private bool sh_disp;
	public Array<string> extra_files;

	public double clat;
	public double clon;

	const OptionEntry[] options = {
		{ "auto-connect", 'a', 0, OptionArg.NONE, null, "auto-connect to first device (sets auto flag)", null},
		{ "build-id", 0, 0, OptionArg.NONE, null, "show build id", null},
		{ "centre", 0, 0, OptionArg.STRING, null, "Centre position (lat lon or named place)", "position"},
		{ "centre-on-home", 'H', 0, OptionArg.NONE, null, "Centre on home", null},
		{ "cli-file", 0, 0, OptionArg.STRING, null, "CLI File", null},
		{ "connect", 'c', 0, OptionArg.NONE, null, "connect to first device (does not set auto flag)", null},
		{ "debug-flags", 0, 0, OptionArg.INT, null, "Debug flags (mask)", null},
		{ "device", 'd', 0, OptionArg.STRING, null, "Serial device", "device-name"},
		{ "dont-maximise", 0, 0, OptionArg.NONE, null, "don't maximise the window", null},
		{ "force-mag", 0, 0, OptionArg.NONE, null, "force mag for vehicle direction", null},
		{ "force-type", 't', 0, OptionArg.INT, null, "Model type", "type-code_no"},
		{ "force4", '4', 0, OptionArg.NONE, null, "Force ipv4", null},
		{ "forward-to", 0, 0, OptionArg.STRING, null, "forward telemetry to", "device-name"},
		{ "full-screen", 0, 0, OptionArg.NONE, null, "open full screen", null},
		{ "kmlfile", 'k', 0, OptionArg.STRING, null, "KML file", "file-name"},
		{ "mission", 'm', 0, OptionArg.STRING, null, "Mission file", "file-name"},
		{ "mod-points", 'M', 0, OptionArg.INT, null, "Modulo points to show in GPS trail", "N"},
		{ "n-points", 'S', 0, OptionArg.INT, null, "Number of points shown in GPS trail", "N"},
		{ "no-poll", 'N', 0, OptionArg.NONE, null, "don't poll for nav info", null},
		{ "no-trail", 'T', 0, OptionArg.NONE, null, "don't display GPS trail", null},
		{ "offline", 0, 0, OptionArg.NONE, null, "force offline proxy mode", null},
		{ "radar-device", 0, 0, OptionArg.STRING_ARRAY, null, "dedicated inav radar device", "device-name"},
		{ "raw-log", 'r', 0, OptionArg.NONE, null, "log raw serial data to file", null},
		{ "really-really-run-as-root", 0, 0, OptionArg.NONE, null, "no reason to ever use this", null},
		{ "rebase", 0, 0, OptionArg.STRING, null, "rebase location (for replay)", "lat,lon"},
		{ "relaxed-msp", 0, 0, OptionArg.NONE, null, "don't check MSP direction flag", null},
		{ "replay-bbox", 'b', 0, OptionArg.STRING, null, "replay bbox log file", "file-name"},
		{ "replay-mwp", 'p', 0, OptionArg.STRING, null, "replay mwp log file", "file-name"},
		{ "rings", 0, 0, OptionArg.STRING, null, "Range rings (number, interval(m)), e.g. --rings 10,20", "number,interval"},
		{ "serial-device", 's', 0, OptionArg.STRING, null, "Serial device", "device_name"},
		{ "version", 'v', 0, OptionArg.NONE, null, "show version", null},
		{ "voice-command", 0, 0, OptionArg.STRING, null, "External speech command", "command string"},
		{null}
	};

	OptionEntry ? find_option(string s) {
		foreach(var o in options) {
			if (s[1] == '-') {
				if(s[2:s.length] == o.long_name) {
					return o;
				}
			} else if (s[1] == o.short_name) {
				return o;
			}
		}
		return null;
	}

	private  VariantDict  check_env_args(string?s) {
		VariantDict v = new VariantDict();
		if(s != null) {
			var sb = new StringBuilder(Mwp.user_args);
			sb.append(s);
			Mwp.user_args = sb.str;

			string []m;
			try {
				Shell.parse_argv(s, out m);
				for(var i = 0; i < m.length; i++) {
					string extra=null;
					string optname = null;
					int iarg;
					var mparts = m[i].split("=");
					optname = mparts[0];
					if (mparts.length > 1) {
						extra = mparts[1];
					}

					var o = find_option(optname);
					if (o != null) {
						if (o.arg !=  OptionArg.NONE && extra == null) {
							extra = m[++i];
						}
						switch(o.arg) {
						case OptionArg.NONE:
							if (o.long_name != null)
								v.insert(o.long_name, "b", true);
							if (o.short_name != 0)
								v.insert(o.short_name.to_string(), "b", true);
							break;
						case OptionArg.STRING:
							if (o.long_name != null)
								v.insert(o.long_name, "s", extra);
							if (o.short_name != 0)
								v.insert(o.short_name.to_string(), "s", extra);
							break;
						case OptionArg.INT:
							iarg = int.parse(extra);
							if (o.long_name != null)
								v.insert(o.long_name, "i", iarg);
							if (o.short_name != 0)
								v.insert(o.short_name.to_string(), "i", iarg);
							break;
						case OptionArg.STRING_ARRAY:
							VariantBuilder builder = new VariantBuilder (new VariantType ("as") );
							if(v.contains(o.long_name)) {
								var ox = v.lookup_value(o.long_name, VariantType.STRING_ARRAY);
								var extras = ox.dup_strv();
								foreach (var se in extras) {
									builder.add ("s",se);
								}
							}
							builder.add ("s", extra);
							v.insert(o.long_name, "as", builder);
							break;

						default:
							MWPLog.message("Error ARG PARSE %s %s\n", o.long_name, o.arg.to_string());
							break;
						}
					}
				}
			} catch (Error e) {
				MWPLog.message("*** Internal Dict Error %s\n", e.message);
			}
		}
		return v;
	}

	private static string? check_virtual(string? os) {
		string hyper = null;
#if UNIX
		string cmd = null;
		switch (os) {
		case "Linux":
			cmd = "systemd-detect-virt";
			break;
		case "FreeBSD":
			cmd = "sysctl kern.vm_guest";
			break;
		}

		if(cmd != null) {
			string strout="";
			size_t len;
			var subp = new ProcessLauncher();
			if (subp.run_argv({cmd}, ProcessLaunch.STDOUT)) {
				var ioc = subp.get_stdout_iochan();
				subp.complete.connect(() => {
						try { ioc.shutdown(false); } catch {}
					});
				try {
					var sts = ioc.read_to_end(out strout, out len);
					if(sts == IOStatus.NORMAL && strout.length > 0) {
						strout = strout.chomp();
						if(os == "Linux")
							hyper = strout;
						else {
							var index = strout.index_of("kern.vm_guest: ");
							if(index != -1)
								hyper = strout.substring(index+"kern.vm_guest: ".length);
						}
					}
				} catch (Error e) {}
			}
			return hyper;
        }

		var subp = new ProcessLauncher();
		if (subp.run_argv({"dmesg"}, ProcessLaunch.STDOUT)) {
			var ioc = subp.get_stdout_iochan();
			string line;
			size_t length = -1;
			subp.complete.connect(() => {
					try { ioc.shutdown(false); } catch {}
				});
			for(;;) {
				try {
					var sts = ioc.read_line (out line, out length, null);
					if (sts != IOStatus.NORMAL || line == null) {
						break;
					}
					line = line.chomp();
					var index = line.index_of("Hypervisor");
					if(index != -1) {
						hyper = line.substring(index);
						break;
					}
				} catch (Error e) {
					break;
				}
			}
		}
#endif
		return hyper;
	}

	private static string? read_env_args() {
		var s1 = read_cmd_opts();
		var s2 = Environment.get_variable("MWP_ARGS");
		var sb = new StringBuilder();
		if(s1.length > 0)
			sb.append(s1);
		if(s2 != null)
			sb.append(s2);

		if(sb.len > 0)
			return sb.str;
		return null;
	}

	private static void read_cmd_file(string fn, ref StringBuilder sb) {
		var file = File.new_for_path(fn);
		try {
			if (file.query_exists ()) {
				var dis = new DataInputStream(file.read());
				string line;
				while ((line = dis.read_line (null)) != null) {
					if(line.strip().length > 0) {
						if(line.has_prefix("#") || line.has_prefix(";")) {
							continue;
						} else if (line.has_prefix("-")) {
							sb.append(line);
							sb.append_c(' ');
						} else if (line.contains("=")) {
							var parts = line.split("=");
							if (parts.length == 2) {
								var ename = parts[0].strip();
								var evar = parts[1].strip();
								Environment.set_variable(ename, evar, true);
							}
						}
					}
				}
			}
		} catch (Error e) {
			MWPLog.message ("%s %s\n", fn, e.message);
		}
	}

	private static string read_cmd_opts() {
		var sb = new StringBuilder ();
		read_cmd_file("/etc/default/mwp", ref sb);
        var confdir = GLib.Path.build_filename(Environment.get_user_config_dir(),"mwp");
        try {
            var dir = File.new_for_path(confdir);
            dir.make_directory_with_parents ();
        } catch {};
		var fn = MWPUtils.find_conf_file("cmdopts");
		if(fn != null) {
			read_cmd_file(fn, ref sb);
		}
		return sb.str;
	}

	public class Application : Adw.Application {
        public Application (string? s) {
            Object (
				application_id: Mwp.MWPID,
				flags: ApplicationFlags.HANDLES_COMMAND_LINE);
#if UNIX
			Unix.signal_add (
				Posix.Signal.INT,
				on_exit,
				Priority.DEFAULT
				);
			Unix.signal_add (
				Posix.Signal.TERM,
				on_exit,
				Priority.DEFAULT
				);
#endif
			var v = check_env_args(s);
			set_opts_from_dict(v);
			add_main_option_entries(options);
			handle_local_options.connect(do_handle_local_options);
		}

		construct {
			extra_files = new Array<string>();
		}

#if UNIX
		private bool on_exit () {
			Mwp.do_exit_tasks();
			release();
			return Source.REMOVE;
		}
#endif
		public override void activate () {
#if UNIX
			if((Posix.geteuid() == 0 || Posix.getuid() == 0)) {
				MWPLog.message("Cowardly refusing to run as root ... for your own safety\n");
				Posix.exit(127);
			}
#endif
			if (active_window == null) {
				show_misc_info();
				new Thread<int> ("glinfo", () => {
						Mwp.get_gl_info();
						return 0;
					});
			}
			base.activate ();
			if (active_window == null) {
				ready = true;
				window = new Mwp.Window (this);
				window.present ();
			} else {
				Cli.parse_cli_files();
			}
		}

		public override bool dbus_register (DBusConnection connection, string object_path) throws Error {
			bool retval = false;
			if( base.dbus_register (connection, object_path)) {
				try {
					MBus.svc = new MBus.Service ();
					MBus.svc.notify["dbus_pos_interval"].connect((s,p) => {
							MBus.dbus_upd_ticks = MBus.svc.dbus_pos_interval / 100;
						});

					connection.register_object ("/org/stronnag/mwp", MBus.svc);
					retval = true;
					//				MWPLog.message("Registered Dbus service %s\n", object_path);
				} catch (IOError e) {
					MWPLog.message ("Failed to register DBus service: %s\n", e.message);
					MBus.svc = null;
				}
			}
			return retval;
		}

		public override void dbus_unregister (DBusConnection connection, string object_path) {
			base.dbus_unregister (connection, object_path);
		}

		private int do_handle_local_options(VariantDict o) {
            // return 0 to stop here ..
			if (o.contains("version")) {
				stdout.printf("%s\n", MwpVers.get_id());
				return 0;
			}

			if (o.contains("build-id")) {
				stdout.printf("%s\n", MwpVers.get_build());
				return 0;
			}
			return -1;
		}

		private int _command_line (ApplicationCommandLine command_line) {
			string[] args = command_line.get_arguments ();
			foreach (var a in args[1:args.length]) {
				extra_files.append_val(a);
			}
			var o = command_line.get_options_dict();
			set_opts_from_dict(o);
			activate();
			return 0;
		}

		public override int command_line (ApplicationCommandLine command_line) {
			hold ();
			int res = _command_line (command_line);
			release ();
			return res;
		}

		private void set_opts_from_dict(VariantDict o) {
			o.lookup("mission", "s", ref mission);
			o.lookup("kmlfile", "s", ref kmlfile);
			o.lookup("replay-mwp", "s", ref rfile);
			o.lookup("replay-bbox", "s", ref bfile);
			o.lookup("cli-file", "s", ref clifile);

			if(!ready) {
				o.lookup("serial-device", "s", ref serial);
				o.lookup("device", "s", ref serial);
				o.lookup("connect", "b", ref mkcon);
				o.lookup("auto-connect", "b", ref autocon);
				o.lookup("no-poll", "b", ref zznopoll);
				o.lookup("no-trail", "b", ref no_trail);
				o.lookup("raw-log", "b", ref rawlog);
				o.lookup("full-screen", "b", ref set_fs);
				o.lookup("dont-maximise", "b", ref no_max);
				o.lookup("force-mag", "b", ref force_mag);
				o.lookup("force-nav", "b", ref force_nc);
				o.lookup("force-type", "i", ref dmrtype);
				o.lookup("force4", "b", ref force4);
				o.lookup("centre-on-home", "b", ref chome);
				o.lookup("debug-flags", "i", ref debug_flags);
				o.lookup("centre", "s", ref llstr);
				o.lookup("rebase", "s", ref rebasestr);
				o.lookup("offline", "b", ref offline);
				o.lookup("n-points", "i", ref stack_size);
				o.lookup("mod-points", "i", ref mod_points);
				o.lookup("rings", "s", ref rrstr);
				o.lookup("voice-command", "s", ref exvox);
				o.lookup("really-really-run-as-root", "b", ref asroot);
				o.lookup("forward-to", "s", ref forward_device);
				if (o.contains("radar-device")) {
					var ox = o.lookup_value("radar-device", VariantType.STRING_ARRAY);
					var rds = ox.dup_strv();
					foreach(var rd in rds) {
						radar_device += rd;
					}
				}
				o.lookup("relaxed-msp", "b", ref relaxed);
				xnopoll = nopoll = zznopoll; // FIXNOPOLL
			}
		}
	}

	static bool dex = true;
	public void do_exit_tasks() {
		if (dex) {
			MWPLog.message("Cleaning up ...\n");
			dex = false;
			Mwp.cleanup();
			if(ready && Mwp.conf.atexit != null && Mwp.conf.atexit.length > 0) {
				new ProcessLauncher().run_command(Mwp.conf.atexit, ProcessLaunch.WAIT);
			}
#if UNIX
			Posix.kill(0, 15);
#endif
		}
	}
}
