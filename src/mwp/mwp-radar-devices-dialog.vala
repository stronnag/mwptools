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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Radar {
	public class RadarDevWindow : Adw.Window {
		internal Gtk.Entry dn;
		private Gtk.Button ok;
		public  bool applied;
		public RadarDevWindow() {
			vexpand = false;
			title = "Radar Device";
			applied = false;
			var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
			box.vexpand = false;

			var tbox = new Adw.ToolbarView();
			var headerBar = new Adw.HeaderBar();
			tbox.add_top_bar(headerBar);

			dn = new Gtk.Entry();
			dn.width_chars = 80;
			dn.placeholder_text = "Device URI/Name";
			dn.valign = Gtk.Align.CENTER;
			var g = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
			g.vexpand = false;
			g.append (new Gtk.Label("Name: "));
			g.append (dn);
			box.append(g);

			var bbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL,2);
			ok = new Gtk.Button.with_label("Apply");
			ok.hexpand = false;
			ok.vexpand = true;
			ok.halign = Gtk.Align.END;
			ok.valign = Gtk.Align.END;

			bbox.halign = Gtk.Align.END;
			bbox.hexpand = true;
			bbox.append(ok);
			bbox.add_css_class("toolbar");
			tbox.add_bottom_bar(bbox);

			tbox.set_content(box);
			set_content(tbox);
			ok.clicked.connect(() => {
					applied = true;
					close();
				});
		}
	}

	namespace Device {
		[GtkTemplate (ui = "/org/stronnag/mwp/radar_devices.ui")]
		public class Dialog : Adw.Window {
			[GtkChild]
			private unowned Gtk.ColumnView rdrlist;
			[GtkChild]
			private unowned Gtk.ColumnViewColumn enable;
			[GtkChild]
			private unowned Gtk.ColumnViewColumn uri;
			[GtkChild]
			private unowned Gtk.ColumnViewColumn remove;
			[GtkChild]
			private unowned Gtk.ScrolledWindow sw;

			[GtkChild]
			private unowned Gtk.Button additem;
			[GtkChild]
			private unowned  Gtk.Button savelist;

			private void setup_factories() {
				var f0 = new Gtk.SignalListItemFactory();
				enable.set_factory(f0);
				f0.setup.connect((f,o) => {
						Gtk.ListItem list_item = (Gtk.ListItem)o;
						var cbtn = new Gtk.CheckButton();
						list_item.set_child(cbtn);
						cbtn.notify["active"].connect((s,p) => {
								RadarDev rd = list_item.get_item() as RadarDev;
								if (((RadarDev)rd).enabled != cbtn.active) {
                                    int idx = Radar.find_radar(rd.name);
                                    Radar.update_active(idx, cbtn.active);
									Radar.items.sort(cmpfunc);
								}
							});

					});
				f0.bind.connect((f,o) => {
						Gtk.ListItem list_item =  (Gtk.ListItem)o;
						var cbtn = list_item.get_child() as Gtk.CheckButton;
						RadarDev rd = list_item.get_item() as RadarDev;
						cbtn.active = ((RadarDev)rd).enabled;
					});

				var f1 = new Gtk.SignalListItemFactory();
				uri.set_factory(f1);
				f1.setup.connect((f,o) => {
						Gtk.ListItem list_item = (Gtk.ListItem)o;
						var label=new Gtk.Entry();
						label.width_chars = 80;
						list_item.set_child(label);
						label.activate.connect(() => {
								var rd = list_item.get_item() as RadarDev;
								bool ena = rd.is_enabled();
								int idx = Radar.find_radar(rd.name);
								//MWPLog.message(":DBG: Find %d for <%s>\n", idx, rd.name);
								var text = label.buffer.text.chomp();
								if (text != rd.name) {
									if(ena) {
										Radar.update_active(idx, false, true);
									} else {
										Radar.items.remove(idx);
									}
									Radar.add_radar(text, false);
									Radar.items.sort(cmpfunc);
								}
							});
					});

				f1.bind.connect((f,o) => {
						Gtk.ListItem list_item =  (Gtk.ListItem)o;
						var rd = list_item.get_item() as RadarDev;
						var label = list_item.get_child() as Gtk.Entry;
						label.buffer.set_text (rd.name.data);
					});

				var f2 = new Gtk.SignalListItemFactory();
				remove.set_factory(f2);

				f2.setup.connect((f,o) => {
						Gtk.ListItem list_item = (Gtk.ListItem)o;
						var btn = new Gtk.Button.from_icon_name("edit-delete-symbolic");
						list_item.set_child(btn);
						btn.clicked.connect(() => {
								var rd = list_item.get_item() as RadarDev;
								int idx = Radar.find_radar(rd.name);
								//MWPLog.message(":DBG: Remove for %d\n", idx);
                                Radar.update_active(idx, false, true);
							});
					});

				var model = new Gtk.SingleSelection(Radar.items);
				rdrlist.set_model(model);
				rdrlist.set_single_click_activate(true);
				rdrlist.set_enable_rubberband(false);
			}

			public Dialog() {
				sw.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
				sw.min_content_height = 100;
				setup_factories();
				sw.propagate_natural_height = true;
				sw.propagate_natural_width = true;

				savelist.clicked.connect(() => {
                        write_out();
					});

				additem.clicked.connect(() => {
						additem.sensitive = false;
						var w = new  RadarDevWindow();
						w.transient_for = this;
						w.close_request.connect(() => {
								if (w.applied) {
									if(w.dn.text != "") {
										Radar.add_radar(w.dn.text, false);
									}
								}
								additem.sensitive = true;
								return false;
							});
						w.present();
					});
			}
		}
	}
}
