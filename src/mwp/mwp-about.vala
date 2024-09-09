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

namespace About {
	public void show_about () {
		string[] developers = { "Jonathan Hudson" };
		string release_notes = "<p>P-release adds the following features:</p>\n<ul><li>GTK4 UI</li>\n  <li>Shumate Map layer.</li>\n  <li>Bug fixes and performance improvements.</li>\n</ul>\n";
		var copyright = "© 2014-%d Jonathan Hudson".printf(new DateTime.now_local().get_year());

		var details = "\"A mission planner for the rest of us\"\n\nCommit: %s\n".printf(MwpVers.get_build());
		var about = new Adw.AboutWindow () {
				transient_for = Mwp.window,
					application_name = "mwp4",
					application_icon = "mwp_icon",
					developer_name = "Jonathan Hudson",
					version = MwpVers.get_id(),
					developers = developers,
					documenters = developers,
					copyright = copyright,
					license_type = Gtk.License.GPL_3_0,
					issue_url = "https://github.com/stronnag/mwptools",
					comments = details,
					website = "https://stronnag.github.io/mwptools/",
					release_notes = release_notes,
					release_notes_version = MwpVers.get_id()
					};
		about.present ();
	}
}