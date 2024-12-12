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

namespace Voltage {
	[Flags]
	public enum Update {
		VOLTS,
		CURR
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/voltage.ui")]
	public class View : Gtk.Box {
		[GtkChild]
		private unowned Gtk.Label voltlabel;
		[GtkChild]
		private unowned Gtk.Label ampslabel;
		[GtkChild]
		private unowned Gtk.Label mahlabel;
		private string[]fuelunits;
		private int licol;

		public View() {
			load_css();
			fuelunits= {"", "%", "mAh", "mWh"};
			licol = -1;
			update_v(0.0f);
			ampslabel.visible=false;
			mahlabel.visible=false;
			ampslabel.set_label("");
			mahlabel.set_label("");
		}

		public void update(Update what) {
			if (Update.VOLTS in what) {
				update_v(Mwp.msp.td.power.volts);
            }
			if (Update.CURR in what) {
				update_c();
            }
		}

		private void load_css() {
			var provider = new Gtk.CssProvider ();
			string cssfile = MWPUtils.find_conf_file("volts.css");
			MWPLog.message("Loaded %s\n", cssfile);
			provider.load_from_file(File.new_for_path(cssfile));
			var stylec = this.get_style_context();
			stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			if(Mwp.conf.vlevels != null) {
				string [] parts;
				parts = Mwp.conf.vlevels.split(";");
				var i = 0;
				foreach (unowned string str in parts) {
					var d = DStr.strtod(str,null);
					Battery.vcol.levels[i].cell = (float)d;
					i++;
				}
			}
		}

		private void update_v(float volts) {
			var vstr = "%.1f".printf(volts);
			int icol = Battery.icol;
			if(icol != licol) {
				var lsc = this.get_style_context();
				if(licol != -1) {
					lsc.remove_class(Battery.vcol.levels[licol].colour);
				}
				lsc.add_class(Battery.vcol.levels[icol].colour);
				licol = icol;
			}
			var vs = "<span font='monospace' size='600%%'>%sv</span>".printf(vstr);
			voltlabel.set_label(vs);
		}

		private void update_c() {
			if (Battery.icol == -1 || Battery.curr.ampsok == false) {
				ampslabel.visible=false;
				mahlabel.visible=false;
				ampslabel.set_label("");
				mahlabel.set_label("");
			} else {
				string ampslbl;
				double ca = Battery.curr.centiA / 100.0;
				if(Battery.curr.centiA > 9999)
					ampslbl = "%.0f".printf(ca);
				else if (Battery.curr.centiA > 99)
					ampslbl = "%.1f".printf(ca);
				else
					ampslbl = "%.2f".printf(ca);

				ampslabel.set_label("<span font='monospace' size='200%%'>%sA</span>".printf(ampslbl));

				if(Battery.curr.mah > 0 && Mwp.conf.smartport_fuel > 0 && Mwp.conf.smartport_fuel < 4) {
					mahlabel.set_label("<span font='monospace' size='200%%'>%5u%s</span>".printf(Battery.curr.mah,fuelunits[Mwp.conf.smartport_fuel]));
				} else {
					mahlabel.set_label("");
				}
			}
			if(Battery.curr.ampsok) {
				ampslabel.visible=true;
				mahlabel.visible=true;
			}
		}
	}
}
