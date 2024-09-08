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
extern int epoxy_glinfo();

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

		MWPLog.message("buildinfo: %s\n", MwpVers.get_build_host());
		MWPLog.message("toolinfo: %s\n", MwpVers.get_build_compiler());
		MWPLog.message("version: %s\n", verstr);
		string os=null;
		MWPLog.message("%s\n", Logger.get_host_info(out os));
		MWPLog.message("WM: %s / %s\n", dmstr, sesstype);
		//		get_gl_info();
		var vstr = check_virtual(os);
		if(vstr == null || vstr.length == 0)
			vstr = "none";
		MWPLog.message("hypervisor: %s\n", vstr);
	}

	public void get_gl_info() {
		if(epoxy_glinfo() != 0) {
			string strout;
			int status;
			string []glexes={"es2_info", "glinfo"};
			foreach (var s in glexes) {
				bool found = (Environment.find_program_in_path(s) != null);
				if(found) {
					StringBuilder sb = new StringBuilder();
					try {
						Process.spawn_command_line_sync (s, out strout, null, out status);
						if(Process.if_exited(status)) {
							if(strout.length > 0) {
								int nm = 0;
								string glversion=null;
								string glvendor=null;
								string glrenderer=null;
								var parts = strout.split("\n");
								foreach (var p in parts) {
									if(p.has_prefix("GL_VERSION: ")) {
										glversion = p["GL_VERSION: ".length:];
										nm++;
									} else if(p.has_prefix("GL_RENDERER: ")) {
										glrenderer = p["GL_RENDERER: ".length:];
										nm++;
									} else if(p.has_prefix("GL_VENDOR: ")) {
										glvendor = p["GL_VENDOR: ".length:];
										nm++;
									}
									if(nm == 3) {
										sb.append(glvendor);
										sb.append_c(' ');
										sb.append(glrenderer);
										sb.append_c(' ');
										sb.append(glversion);
								break;
									}
								}
							}
							MWPLog.message("GL: %s\n", sb.str);
							break;
						}
					} catch (SpawnError e) {
						MWPLog.message("%s : %s\n", s, e.message);
					}
				}
			}
		}
	}
}
