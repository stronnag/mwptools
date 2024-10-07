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


int main (string[] args) {
	MWPUtils.set_app_name("mwp");
	Environment.set_application_name ("mwp");
	var s = Mwp.read_env_args();
    StringBuilder sb = new StringBuilder();
    bool rtn = false;
    foreach(var a in args) {
		if (a == "--version" || a == "-v") {
			stdout.printf("%s ", MwpVers.get_id());
			rtn = true;
		}
		if (a == "--build-id") {
			stdout.printf("%s ", MwpVers.get_build());
			rtn = true;
		}
		sb.append(a);
		sb.append_c(' ');
    }
    if(rtn) {
		stdout.putc('\n');
		return 0;
    }
	Gst.init (ref args);
    Mwp.user_args = sb.str;
	var app = new Mwp.Application (s);
	var ret = app.run (args);
	Mwp.do_exit_tasks();
	return ret;
}
