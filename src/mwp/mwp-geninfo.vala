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

internal const string GSK_NOTICE="""Setting "GSK_RENDERER=cairo" for maximum GPU compatibility.
	Export an alternate value from `~/.config/mwp/cmdopts`, `.profile`,
	`/etc/environment` or `~/.config/environment.d/` to use a potentially
	more performant setting, see:
	https://stronnag.github.io/mwptools/mwp-Gtk4-migration-guide/#display-variables-tweaks
""";

namespace Mwp {
	public void show_misc_info () {
		MWPLog.message("%s\n", Mwp.user_args);
		Mwp.user_args = null;
		var sb = new StringBuilder("mwp ");
		var s_0 = MwpVers.get_build();
		var s_1 = MwpVers.get_id();

		sb.append(s_0);
		sb.append_c(' ');
		sb.append(s_1);
		var verstr = sb.str;
		string[] dms = {
			"XDG_SESSION_DESKTOP", "DESKTOP_SESSION", "XDG_CURRENT_DESKTOP"
		};
		string dmstr = null;
		foreach (var dx in dms)  {
			dmstr = Environment.get_variable(dx);
			if (dmstr != null)
				break;
		}
		if (dmstr == null) {
			dmstr = "Unknown DE";
		}

		var sesstype = Environment.get_variable("XDG_SESSION_TYPE");
		if (sesstype == null) {
			sesstype = "null session";
		}

		MWPLog.message("buildinfo: %s\n", MwpVers.get_build_host());
		MWPLog.message("toolinfo: %s\n", MwpVers.get_build_compiler());
		MWPLog.message("version: %s\n", verstr);
		string os=null;
		MWPLog.message("%s\n", Logger.get_host_info(out os));
		MWPLog.message("Gtk: %d.%d.%d (build) / %u.%u.%u (runtime)\n", Gtk.MAJOR_VERSION, Gtk.MINOR_VERSION,Gtk.MICRO_VERSION, Gtk.get_major_version(), Gtk.get_minor_version(), Gtk.get_micro_version());
		MWPLog.message("Adw: %d.%d.%d (build) / %u.%u.%u (runtime)\n", Adw.MAJOR_VERSION, Adw.MINOR_VERSION,Adw.MICRO_VERSION, Adw.get_major_version(), Adw.get_minor_version(), Adw.get_micro_version());
		MWPLog.message("GLib: %d.%d.%d (build) / %u.%u.%u (runtime)\n", GLib.Version.MAJOR, GLib.Version.MINOR,GLib.Version.MICRO, GLib.Version.major, GLib.Version.minor, GLib.Version.micro);
		MWPLog.message("Shumate: %d.%d.%d\n", Shumate.MAJOR_VERSION, Shumate.MINOR_VERSION, Shumate.MICRO_VERSION);
		sb.erase();
		sb.append("WM: ");
		sb.append(dmstr);
		sb.append(" / ");
		sb.append(sesstype);
		string []evars = {"GDK_BACKEND", "GSK_RENDERER"};
		foreach (var ev in evars) {
			var e = Environment.get_variable(ev);
			if (e != null) {
				sb.append_printf(" %s=%s", ev, e);
			} else if (ev == "GSK_RENDERER") {
				MWPLog.message(GSK_NOTICE);
				Environment.set_variable(ev, "cairo", true);
			}
		}
		sb.append_c('\n');
		MWPLog.message(sb.str);

		var vstr = check_virtual(os);
		if(vstr == null || vstr.length == 0)
			vstr = "none";
		MWPLog.message("hypervisor: %s\n", vstr);
	}

	public void get_gl_info() {
		string line;
		string []glexes={"es2_info", "glxinfo"};
		foreach (var s in glexes) {
			bool found = (Environment.find_program_in_path(s) != null);
			if(found) {
				int nm = 0;
				StringBuilder sb = new StringBuilder();
				try {
					line = "";
					var subp = new ProcessLauncher();
					if (subp.run_argv({s}, ProcessLaunch.STDOUT)) {
						var ioc = subp.get_stdout_iochan();
						subp.complete.connect( () => {
								try {ioc.shutdown(false);} catch {}
							});

						string glversion=null;
						string glvendor=null;
						string glrenderer=null;
						for(;;) {
							var sts = ioc.read_line (out line, null, null);
							if (sts != IOStatus.NORMAL || line == null) {
								break;
							}
							if(line.length > 0) {
								if (s == "es2_info") {
									if(line.has_prefix("GL_VERSION: ")) {
										glversion = line["GL_VERSION: ".length:];
										nm++;
									} else if(line.has_prefix("GL_RENDERER: ")) {
										glrenderer = line["GL_RENDERER: ".length:];
										nm++;
									} else if(line.has_prefix("GL_VENDOR: ")) {
										glvendor = line["GL_VENDOR: ".length:];
										nm++;
									}
								}  else {
									if(line.has_prefix("    Version: ")) {
										glversion = line["    Version: ".length:];
										nm++;
									} else if(line.has_prefix("    Device: ")) {
										glrenderer = line["    Device: ".length:];
										nm++;
									} else if(line.has_prefix("    Vendor: ")) {
										glvendor = line["    Vendor: ".length:];
										nm++;
									}
								}
							}
							if(nm == 3) {
								sb.append(glvendor.chomp());
								sb.append_c(' ');
								sb.append(glrenderer.chomp());
								sb.append_c(' ');
								sb.append(glversion.chomp());
								sb.append_printf(" (%s)", s);
								MWPLog.message("GL: %s\n", sb.str);
								break;
							}
						}
					}
				} catch (Error e) {
					MWPLog.message("%s : %s\n", s, e.message);
				}
				if(nm == 3)
					break;
			}
		}
	}
}
