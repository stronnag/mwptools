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

namespace MissionManager {
	public void show_tote() {
		var tote = new Tote();
  		tote.present();
	}

	public class Tote : Adw.Window {
		GLib.MenuModel mmodel;
		GLib.ListStore lstore;
		Gtk.MultiSelection model;
        GLib.SimpleActionGroup dg;

		Gtk.ColumnViewColumn c0;
		Gtk.ColumnViewColumn c1;
		Gtk.ColumnViewColumn c2;
		Gtk.ColumnViewColumn c3;
		Gtk.ColumnViewColumn c4;
		Gtk.ColumnViewColumn c5;
		Gtk.ColumnViewColumn c6;
		Gtk.ColumnViewColumn c7;
		Gtk.ColumnViewColumn c8;

		Mission ms;

		public Tote() {
			ms = MissionManager.current();

			var lv = new Gtk.ColumnView(null);
			lv.show_column_separators = true;
			lv.show_row_separators = true;
			var f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("No", f0);
			lv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = list_item.get_item() as MissionItem;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.no.to_string());
					mi.bind_property("no", label, "label", BindingFlags.SYNC_CREATE);
				});

			var f1 = new Gtk.SignalListItemFactory();
			c1 =new  Gtk.ColumnViewColumn("Action", f1);
			// c1.expand = false;
			// c1.fixed_width = 120;
			lv.append_column(c1);
			f1.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f1.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = list_item.get_item() as MissionItem;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(Msp.get_wpname(mi.action));
					mi.notify["action"].connect((s,p) => {
							label.set_text(Msp.get_wpname(((MissionItem)s).action));
						});
					var ds = new Gtk.DragSource();
					var dt = new Gtk.DropTarget(typeof (int), Gdk.DragAction.COPY);
					label.add_controller(ds);
					label.add_controller(dt);

					var ctl = new Gdk.ContentProvider.for_value(mi.no);
					ds.set_content(ctl);
					dt.accept.connect((d) => {
							return true;
						});
					dt.drop.connect((tgt, val, x, y) => {
							var dest_pos = mi.no;
							var orig_pos = (int)val;
							var h = tgt.get_widget().get_height();
							if( y > h/2) {
								dest_pos += 1;
								//print("Below\n");
							} else {
								//print("Above\n");
							}
							MsnTools.swap(ms, orig_pos, dest_pos);
							return true;
						});
					/// ------------
				});

			var f2 = new Gtk.SignalListItemFactory();
			c2 = new Gtk.ColumnViewColumn("Latitude", f2);
			lv.append_column(c2);
			f2.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f2.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = list_item.get_item() as MissionItem;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.format_lat());
					mi.notify["lat"].connect((s,p) => {
							label.set_text(((MissionItem)s).format_lat());
						});
				});

			var f3 = new Gtk.SignalListItemFactory();
			c3 = new Gtk.ColumnViewColumn("Longitude", f3);
			lv.append_column(c3);
			f3.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f3.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = list_item.get_item() as MissionItem;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.format_lon());
					mi.notify["lon"].connect((s,p) => {
							label.set_text(((MissionItem)s).format_lon());
						});
				});

			var f4 = new Gtk.SignalListItemFactory();
			c4 = new Gtk.ColumnViewColumn("Altitude", f4);
			lv.append_column(c4);
			f4.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f4.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = (MissionItem)list_item.get_item ();
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.format_alt());
					mi.notify["alt"].connect((s,p) => {
							label.set_text(((MissionItem)s).format_alt());
						});
				});

			var f5 = new Gtk.SignalListItemFactory();
			c5 = new Gtk.ColumnViewColumn("Param1", f5);
			lv.append_column(c5);
			f5.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f5.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = list_item.get_item() as MissionItem;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.format_p1());
					mi.notify["param1"].connect((s,p) => {
							label.set_text(((MissionItem)s).format_p1());
						});
				});

			var f6 = new Gtk.SignalListItemFactory();
			c6 = new Gtk.ColumnViewColumn("Param2", f6);
			lv.append_column(c6);
			f6.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f6.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = list_item.get_item() as MissionItem;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.format_p2());
					mi.notify["param2"].connect((s,p) => {
							label.set_text(((MissionItem)s).format_p2());
						});
				});

			var f7 = new Gtk.SignalListItemFactory();
			c7 = new Gtk.ColumnViewColumn("Param3", f7);
			lv.append_column(c7);
			f7.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f7.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = list_item.get_item() as MissionItem;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.format_p3());
					mi.notify["param3"].connect((s,p) => {
							label.set_text(((MissionItem)s).format_p3());
						});
				});

			var f8 = new Gtk.SignalListItemFactory();
			c8 = new Gtk.ColumnViewColumn("Flags", f8);
			lv.append_column(c8);
			f8.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f8.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					MissionItem mi = list_item.get_item() as MissionItem;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.format_flag());
					mi.notify["flag"].connect((s,p) => {
							label.set_text(((MissionItem)s).format_flag());
						});
				});

			title = "Mission Items";
			var sbuilder = new Gtk.Builder.from_resource ("/org/stronnag/mwp/totemenu.ui");
			mmodel = sbuilder.get_object("ms-menu") as GLib.MenuModel;

			var sw = new Gtk.ScrolledWindow();

			var box = new Gtk.Box(Gtk.Orientation.VERTICAL,4);
			var header_bar = new Adw.HeaderBar();
			box.append(header_bar);

			lstore = new GLib.ListStore(typeof(MissionItem));
			model = new Gtk.MultiSelection(lstore);
			lv.set_model(model);
			for(var i = 0; i < ms.npoints; i++) {
				lstore.append(ms.points[i]);
			}
			ms.changed.connect(() => {
					reload();
				});

			sw.set_child(lv);
			lv.hexpand = true;
			lv.vexpand = true;
			sw.vexpand = true;
			//box.hexpand = true;
			box.vexpand = true;
			box.append(sw);
			set_content(box);
			set_default_size(640,640);
			set_transient_for(Mwp.window);
			set_tote_action();

			var bc = new Gtk.GestureClick();
			((Gtk.Widget)lv).add_controller(bc);
			bc.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
			bc.set_button(3);
			bc.pressed.connect((n,x,y) => {
					int rn = Utils.get_row_at(lv, x, y);
					MT.mtno = rn+1;
					popmenuat(lv, x, y);
				});

			model.selection_changed.connect((n,l) => {
					var bs = model.get_selection_in_range (0, ms.npoints);
					if (bs.is_empty())
						return;

					var minb = bs.get_minimum();
					switch(ms.points[minb].action) {
					case Msp.Action.WAYPOINT:
						c5.title="Speed";
						c6.title="Param2";
						break;
					case Msp.Action.POSHOLD_TIME:
						c5.title="Time";
						c6.title="Speed";;
						break;
					case Msp.Action.LAND:
						c5.title="Speed";
						c6.title="ElvAdj";
						break;
					case Msp.Action.JUMP:
						c5.title="Target";
						c6.title="Repeat";
						break;
					case Msp.Action.SET_HEAD:
						c5.title="Heading";
						c6.title="Param2";
						break;
					default:
						c5.title="Param1";
						c6.title="Param2";
						break;
					}
				});
		}

		void popmenuat(Gtk.Widget w, double x, double y) {
			var pop = new Gtk.PopoverMenu.from_model(mmodel);
			Gdk.Rectangle rect = { (int)x, (int)y, 1, 1,};
			pop.set_pointing_to(rect);
			pop.set_parent(w);
			pop.margin_top = 8;
			pop.margin_bottom = 8;
			pop.popup();
		}

        bool set_poi_ok() {
            foreach(var mi in ms.points) {
                if(mi.action == Msp.Action.SET_POI) {
                    return true;
                }
            }
            return false;
        }

		void reload() {
			lstore.splice(0, lstore.n_items, ms.points);
            MwpMenu.set_menu_state(dg, "addshape", set_poi_ok());
		}

		void set_tote_action() {
			dg = new GLib.SimpleActionGroup();
			GLib.SimpleAction saq;

			saq = new GLib.SimpleAction("addshape",null);
			saq.activate.connect(() =>	{
					var ms = MissionManager.current();
					var sp = new Shape.Dialog();
					int idx = ms.get_index(MT.mtno);
					sp.get_values.connect((pts) => {
							MsnTools.add_shape(ms, MT.mtno, pts);
						});
					sp.get_points(ms.points[idx].lat, ms.points[idx].lon);
				});
			dg.add_action(saq);

			saq = new GLib.SimpleAction("deltaloc",null);
			saq.activate.connect(() =>	{
					var bs = model.get_selection_in_range (0, ms.npoints);
					if(!bs.is_empty()) {
						var ms = MissionManager.current();
						var dd = new Delta.Dialog();
						dd.get_deltas(false);
						dd.get_values.connect((dlat, dlon, ialt, move_home) => {
								MsnTools.delta_updates(ms, bs, dlat, dlon, ialt, move_home);
							});
					}
				});
			dg.add_action(saq);

			saq = new GLib.SimpleAction("delete",null);
			saq.activate.connect(() =>	{
					var bs = model.get_selection_in_range (0, ms.npoints);
					if(!bs.is_empty()) {
						MsnTools.delete_range(ms, bs);
					}
				});
			dg.add_action(saq);

			saq = new GLib.SimpleAction("setalts",null);
			saq.activate.connect(() =>	{
					var bs = model.get_selection_in_range (0, ms.npoints);
					if(!bs.is_empty()) {
						var ms = MissionManager.current();
						var dd = new Alt.Dialog();
						dd.get_alt();
						dd.get_value.connect((v) => {
								MsnTools.alt_updates(ms, bs, v);
							});
					}
				});
			dg.add_action(saq);

			saq = new GLib.SimpleAction("setspeeds",null);
			saq.activate.connect(() =>	{
					var bs = model.get_selection_in_range (0, ms.npoints);
					if(!bs.is_empty()) {
						var ms = MissionManager.current();
						var dd = new Speed.Dialog();
						dd.get_speed();
						dd.get_value.connect((v) => {
								MsnTools.speed_updates(ms, bs, v, false);
							});
					}
				});
			dg.add_action(saq);

			saq = new GLib.SimpleAction("setzerospeeds",null);
			saq.activate.connect(() =>	{
					var bs = model.get_selection_in_range (0, ms.npoints);
					if(!bs.is_empty()) {
						var ms = MissionManager.current();
						var dd = new Speed.Dialog();
						dd.get_speed();
						dd.get_value.connect((v) => {
								MsnTools.speed_updates(ms, bs, v, true);
							});
					}
				});
			dg.add_action(saq);

			saq = new GLib.SimpleAction("fbh",null);
			saq.activate.connect(() =>	{
					var bs = model.get_selection_in_range (0, ms.npoints);
					if(!bs.is_empty()) {
						MsnTools.fbh_toggle(ms, bs);
					}
				});
			dg.add_action(saq);


			saq = new GLib.SimpleAction("tersana",null);
			saq.activate.connect(() =>	{
					tadialog.run();
				});
			dg.add_action(saq);

			saq = new GLib.SimpleAction("losana",null);
			saq.activate.connect(() =>	{
					los_analysis(MT._mk.no);
				});
			dg.add_action(saq);

			this.insert_action_group("mtote", dg);
		}
	}
}