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

namespace Radar {
	private struct RadarDev {
		MWSerial dev;
		string name;
		uint tid;
	}

	private RadarDev[] radardevs;
	public RadarCache radar_cache;
	public RadarView radarv;


	public bool lookup_radar(string s) {
		foreach (var r in radardevs) {
			if (r.name == s) {
				MWPLog.message("Found radar %s\n", s);
				return true;
			}
		}
		return false;
	}

	public void display() {
		if(radarv.vis) {
			radarv.hide();
		} else {
			radarv.present();
		}
		radarv.vis = !radarv.vis;
	}

	public void update(uint rk, bool verbose) {
		radarv.update(rk, verbose);
	}

	public bool upsert(uint k, RadarPlot v) {
		return radar_cache.upsert(k,v);
	}

	public void init() {
		radar_cache = new Radar.RadarCache();
		radarv = new RadarView();
		Radar.init_icons();

		foreach (var rd in Mwp.radar_device) {
			var parts = rd.split(",");
			foreach(var p in parts) {
				var pn = p.strip();
				if (pn.has_prefix("sbs://")) {
					MWPLog.message("Set up SBS radar device %s\n", pn);
					var sbs = new ADSBReader(pn);
					sbs.result.connect((s) => {
							if (s == null) {
								Timeout.add_seconds(60, () => {
										sbs.line_reader.begin();
										return false;
									});
							} else {
								var px = sbs.parse_csv_message((string)s);
								if (px != null) {
									decode_sbs(px);
								}
							}
						});
					sbs.line_reader.begin();
				} else if (pn.has_prefix("jsa://")) {
					MWPLog.message("Set up JSA radar device %s\n", pn);
					var jsa = new ADSBReader(pn, 37007);
					jsa.result.connect((s) => {
							if (s == null) {
								Timeout.add_seconds(60, () => {
										jsa.line_reader.begin();
										return false;
									});
							} else {
								decode_jsa((string)s);
							}
						});
					jsa.line_reader.begin();
				} else if (pn.has_prefix("pba://")) {
#if PROTOC
					MWPLog.message("Set up PSA radar device %s\n", pn);
					var pba = new ADSBReader(pn, 38008);
					pba.result.connect((s) => {
							if (s == null) {
								Timeout.add_seconds(60, () => {
										pba.packet_reader.begin();
										return false;
									});
							} else {
								decode_pba(s);
							}
						});
					pba.packet_reader.begin();
#else
					MWPLog.message("mwp not compiled with protobuf-c\n");
#endif

				} else if (pn.has_prefix("http://") || pn.has_prefix("https://")) {
					uint8 htype = 0;
					if(pn.has_suffix(".pb")) {
						htype = 1;
					} else if(pn.has_suffix(".json")) {
						htype = 2;
					}
					if(htype != 0) {
						MWPLog.message("Set up http radar device %s\n", pn);
						var httpa = new ADSBReader.web(pn);
						httpa.result.connect((s) => {
								if (s == null) {
									Timeout.add_seconds(60, () => {
											httpa.poll();
											return false;
										});
								} else {
									if(htype == 1) {
										decode_pba(s);
									} else {
										s[s.length-1] = 0;
										decode_jsa((string)s);
									}
								}
							});
						httpa.poll();
					}
				} else {
					RadarDev r = {};
					r.name = pn;
					MWPLog.message("Set up radar device %s\n", r.name);
					r.dev = new MWSerial();
					r.dev.set_mode(MWSerial.Mode.SIM);
					r.dev.set_pmask(MWSerial.PMask.INAV);
					r.dev.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
							MspRadar.handle_radar(s, cmd,raw,len,xflags,errs);
						});
					radardevs += r;
				}
			}
		}

		foreach (var r in radardevs) {
			try_radar_dev(r);
		}

		Timeout.add_seconds(5, () => {
				radar_periodic();
				return true;
			});
	}

	private void radar_periodic() {
		var now = new DateTime.now_local();

		for(var i = 0; i < radar_cache.size(); i++) {
			var r = radar_cache.get(i);
			if (r != null) {
				uint rk = r.id;
				var is_adsb = ((r.source & RadarSource.M_ADSB) != 0);
				var staled = 12*TimeSpan.SECOND;
				var deled = 60*TimeSpan.SECOND;
				var hided = 30*TimeSpan.SECOND;;
				if (!is_adsb) {
					staled *= 10;
					deled *= 10;
					hided *= 10;
				}
				var delta = now.difference(r.dt);
				bool rdebug = ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE);
				if (delta > deled) {
					if (rdebug) {
						MWPLog.message("TRAF-DEL %X %u %s %s len=%u\n",
									   rk, r.state, r.dt.format("%T"),
									   is_adsb.to_string(), radar_cache.size());
					}
					if(is_adsb) {
						radarv.remove(rk);
						Radar.remove_radar(rk);
						radar_cache.remove(rk);
					}
				} else if(delta > hided) {
					if(rdebug)
						MWPLog.message("TRAF-HID %X %s %u %u\n",
									   rk, r.name, r.state, radar_cache.size());
					if(is_adsb) {
						r.state = 2; // hidden
						r.alert = RadarAlert.SET;
						radar_cache.upsert(rk, r);
						radarv.update(rk, ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE));
						if (r.posvalid) {
							Radar.set_radar_hidden(rk);
						}
					}
				} else if(delta > staled && r.state != 0 && r.state != 3) {
					if(rdebug)
						MWPLog.message("TRAF-STALE %X %s %u %u\n",
									   rk, r.name, r.state, radar_cache.size());
					r.state = 3; // stale
					r.alert = RadarAlert.SET;
					radar_cache.upsert(rk, r);
					radarv.update(rk, ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE));
					if(r.posvalid) {
						Radar.set_radar_stale(rk);
					}
				}
			}
		}
	}

    private void try_radar_dev(RadarDev r) {
		// FIXME 		if(is_shutdown) return;
		if(!r.dev.available) {
			r.dev.open_async.begin(r.name, 0, (obj,res) => {
					var ok = r.dev.open_async.end(res);
					if (ok) {
						r.dev.setup_reader();
						MWPLog.message("start radar reader %s\n", r.name);
						// FIXME
						/*
						if(rawlog)
							r.dev.raw_logging(true);
						*/
					} else {
						string fstr;
						r.dev.get_error_message(out fstr);
						MWPLog.message("Radar reader %s\n", fstr);
						r.tid = Timeout.add_seconds(15, () => {
								r.tid = 0;
								try_radar_dev(r);
								return false;
							});
					}
				});
		}
    }


	public class RadarView : Adw.Window {
		internal bool vis;
		private int64 last_sec;

		Gtk.Label label;
		Gtk.ListStore listmodel;
		Gtk.Button[] buttons;
		Gtk.TreeView view;

		enum Column {
			SID,
			NAME,
			LAT,
			LON,
			ALT,
			COURSE,
			SPEED,
			STATUS,
			LAST,
			RANGE,
			BEARING,
			CATEGORY,
			ALERT,
			ID,
			NO_COLS
		}

		enum Buttons {
			CENTRE,
			HIDE,
			CLOSE
		}

		public enum Status {
			UNDEF = 0,
			ARMED = 1,
			HIDDEN =2,
			STALE = 3,
			ADSB = 4,
			SBS = 5
		}

		~RadarView() {
			foreach (var r in radardevs) {
				if (r.tid != 0) {
					Source.remove(r.tid);
				}
				if(r.dev != null && r.dev.available)
					r.dev.close();
			}
		}

		const double TOTHEMOON = -9999.0;

		public static string[] status = {"Undefined", "Armed", "Hidden", "Stale", "ADS-B", "SDR"};
		public RadarView () {
			set_transient_for(Mwp.window);
			vis = false;
			last_sec = 0;

			view = new Gtk.TreeView ();
			var sbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
			var header_bar = new Adw.HeaderBar();
			sbox.append(header_bar);
			var scrolled = new Gtk.ScrolledWindow ();
			set_default_size (900, 400);
			title = "Radar & Telemetry Tracking";
			view.hexpand = true;
			view.vexpand = true;
			setup_treeview (view);
			label = new Gtk.Label ("");
			var grid = new Gtk.Grid ();
			scrolled.set_child(view);

			buttons = {
				new Gtk.Button.with_label ("Centre on swarm"),
				new Gtk.Button.with_label ("Hide symbols"),
				new Gtk.Button.with_label ("Close")
			};

			bool hidden = false;

			buttons[Buttons.HIDE].clicked.connect (() => {
					if(!hidden) {
						buttons[Buttons.HIDE].label = "Show symbols";
						Gis.rm_layer.hide();
					} else {
						buttons[Buttons.HIDE].label = "Hide symbols";
						Gis.rm_layer.show();
					}
					hidden = !hidden;
				});

			buttons[Buttons.CLOSE].clicked.connect (() => {
					hide();
					vis = false;
				});

			buttons[Buttons.CENTRE].clicked.connect (() => {
					zoom_to_swarm();
				});

			buttons[Buttons.CENTRE].sensitive = false;
			var bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            // The number of pixels to place between children:
			bbox.set_spacing (5);

            // Add buttons to our ButtonBox:
			foreach (unowned Gtk.Button button in buttons) {
				button.halign = Gtk.Align.END;
				bbox.append (button);
			}

			Gtk.Box box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
			box.append(label);
			bbox.halign = Gtk.Align.END;
			bbox.hexpand = true;
			box.append (bbox);
			grid.hexpand = true;
			grid.vexpand = true;
			grid.attach (scrolled, 0, 0, 1, 1);
			grid.attach (box, 0, 1, 1, 1);
			sbox.append(grid);
			set_content (sbox);
			close_request.connect (() => {
					hide();
					vis = false;
					return true;
				});
		}

		private string source_id(uint8 sid) {
			switch(sid) {
			case RadarSource.INAV:
				return "I";
			case RadarSource.TELEM:
				return "T";
			case RadarSource.MAVLINK:
				return "A";
			case RadarSource.SBS:
				return "S";
			}
			return "?";
		}

		private void zoom_to_swarm() {
			int n = 0;
			double alat = 0;
			double alon = 0;
			Gtk.TreeIter iter;

			for(bool next=listmodel.get_iter_first(out iter); next;
				next=listmodel.iter_next(ref iter)) {
				GLib.Value cell;
				listmodel.get_value (iter, Column.ID, out cell);
				var rk = (uint)cell;
				var r = Radar.radar_cache.lookup(rk);
				alat += r.latitude;
				alon += r.longitude;
				n++;
			}
			if(n != 0) {
				alat /= n;
				alon /= n;
				Gis.map.center_on(alat, alon);
			}
		}

		private void show_number() {
			int n_rows = listmodel.iter_n_children(null);
			int stale = 0;
			int hidden = 0;
			Gtk.TreeIter iter;

			buttons[Buttons.CENTRE].sensitive = (n_rows != 0);

			for(bool next=listmodel.get_iter_first(out iter); next; next=listmodel.iter_next(ref iter)) {
				GLib.Value cell;
				listmodel.get_value (iter, Column.STATUS, out cell);
				var status = (string)cell;
				if(status.has_prefix("Stale"))
					stale++;
				if(status.has_prefix("Hidden"))
					hidden++;
			}
			var sb = new StringBuilder("Targets: ");
			int live = n_rows - stale - hidden;
			sb.append_printf("%d", n_rows);
			if (live > 0 && (stale+hidden) > 0)
				sb.append_printf("\tLive: %d", live);
			if (stale > 0)
				sb.append_printf("\tStale: %d", stale);
			if (hidden > 0)
				sb.append_printf("\tHidden: %d", hidden);

			label.set_text (sb.str);
		}

		private bool find_entry(uint rid, out Gtk.TreeIter iter) {
			bool found = false;
			for(bool next=listmodel.get_iter_first(out iter); next; next=listmodel.iter_next(ref iter)) {
				GLib.Value cell;
				listmodel.get_value (iter, Column.ID, out cell);
				var id = (uint)cell;
				if(id == rid) {
					found = true;
					break;
				}
			}
			return found;
		}

		public void remove (uint rid) {
			Gtk.TreeIter iter;
			var found = find_entry(rid, out iter);
			if (found) {
				listmodel.remove(ref iter);
				show_number();
			} else {
				MWPLog.message("Radar view failed for %X\n", rid);
			}
		}

		private void set_cell_text_bg(Gtk.TreeModel model, Gtk.TreeIter iter, Gtk.CellRenderer cell, string? s) {
			Value v;
			model.get_value(iter, Column.ALERT, out v);
			var val = (uint)v;
			if ((val & RadarAlert.ALERT) == RadarAlert.ALERT) {
				cell.cell_background = "red";
				cell.cell_background_set = true;
			} else {
				cell.cell_background_set = false;
			}
			cell.set_property("text", s);
		}

		public void update (uint rk, bool verbose = false) {
			var dt = new DateTime.now_local ();
			double idm = TOTHEMOON;
			uint cse =0;
			uint8 htype;
			double hlat, hlon;
			string ga_bearing;
			string ga_alt;
			string ga_speed;

			var r = Radar.radar_cache.lookup(rk);
			if (r == null)
				return;

			var alert = r.alert;
			// FIXME
			/*
			if(Mwp.any_home(out htype, out hlat, out hlon)) {
				double c,d;
				Geo.csedist(hlat, hlon, r.latitude, r.longitude, out d, out c);
				idm = d*1852.0; // nm to m
				cse = (uint)c;
				if((r.source & RadarSource.M_ADSB) != 0) {
					if(Mwp.conf.radar_alert_altitude > 0 && Mwp.conf.radar_alert_range > 0 &&
					   r.altitude < Mwp.conf.radar_alert_altitude && idm < Mwp.conf.radar_alert_range) {
						r.alert = RadarAlert.ALERT;
						var this_sec = dt.to_unix();
						if(r.state > Status.STALE && this_sec >= last_sec + 2) {
						Mwp.play_alarm_sound(MWPAlert.GENERAL);
							last_sec =  this_sec;
						}
					} else {
						r.alert = RadarAlert.NONE;
					}
				}
			}
			*/
			if (alert != r.alert) {
				r.alert |= RadarAlert.SET;
			}

			if(Mwp.conf.max_radar_altitude > 0 && r.altitude > Mwp.conf.max_radar_altitude) {
				if(verbose) {
					MWPLog.message("RADAR: Not listing %s at %.lf m\n", r.name, r.altitude);
				}
				return;
			}

			Gtk.TreeIter iter;
			var found = find_entry(rk, out iter);
			if(!found) {
				listmodel.append (out iter);
				listmodel.set (iter, Column.ID, rk);
			}

			if(r.state >= RadarView.status.length)
				r.state = Status.UNDEF;
			var stsstr = "%s / %u".printf(RadarView.status[r.state], r.lq);
			//ga_range = "";
			if (idm == TOTHEMOON) {
				ga_bearing = "";
			} else {
				ga_bearing = "%u°".printf(cse);
			}

			if((r.source & RadarSource.M_ADSB) != 0) {
				ga_alt = Units.ga_alt(r.altitude);
				ga_speed = Units.ga_speed(r.speed);
				if (idm == TOTHEMOON && r.srange != 0xffffffff) {
					idm = (double)(r.srange);
				}
				//			if (idm != TOTHEMOON) {
				//	ga_range = Units.ga_range(idm);
				//}
			} else {
				ga_alt = "%.0f %s".printf(Units.distance(r.altitude), Units.distance_units());
				ga_speed = "%.0f %s".printf(Units.speed(r.speed), Units.speed_units());
			}

			listmodel.set (iter,
						   Column.SID, source_id(r.source),
						   Column.NAME,r.name,
						   Column.LAT, PosFormat.lat(r.latitude, Mwp.conf.dms),
						   Column.LON, PosFormat.lon(r.longitude, Mwp.conf.dms),
						   Column.ALT, ga_alt,
						   Column.COURSE, "%d °".printf(r.heading),
						   Column.SPEED, ga_speed,
						   Column.STATUS, stsstr);

			if(r.state == Status.ARMED || r.state == Status.ADSB || r.state == Status.SBS) {
				listmodel.set (iter, Column.LAST, r.dt.format("%T"));
			}

			var scat = CatMap.to_category(r.etype);
			listmodel.set (iter,
						   Column.RANGE, idm,
						   Column.BEARING, ga_bearing,
						   Column.CATEGORY, scat,
						   Column.ALERT, alert);
			show_number();
			Radar.radar_cache.upsert(rk, r);
		}

		private void setup_treeview (Gtk.TreeView view) {
			listmodel = new Gtk.ListStore (Column.NO_COLS,
										   typeof (string),
										   typeof (string),
										   typeof (string),
										   typeof (string),
										   typeof (string),
										   typeof (string),
										   typeof (string),
										   typeof (string),
										   typeof (string),
										   typeof (double),
										   typeof (string),
										   typeof (string),
										   typeof (uint),
										   typeof (uint));

			view.set_model (listmodel);
			var cell = new Gtk.CellRendererText ();

            /* 'weight' refers to font boldness.
             *  400 is normal.
             *  700 is bold.
             */
			//        cell.set ("weight_set", true);
			//        cell.set ("weight", 700);

            /*columns*/
			view.insert_column_with_attributes (-1, "*",
												cell, "text",
												Column.SID);

			view.insert_column_with_attributes (-1, "Id",
												cell, "text",
												Column.NAME);

			var col = view.get_column(Column.NAME);
			col.set_cell_data_func(cell, (col,_cell, model, iter) => {
					Value v;
					model.get_value(iter, Column.NAME, out v);
					set_cell_text_bg(model, iter, _cell, (string)v);
				});

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Latitude", cell, "text", Column.LAT);

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Longitude", cell, "text", Column.LON);

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Altitude", cell, "text", Column.ALT);

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Course", cell, "text", Column.COURSE);

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Speed", cell, "text", Column.SPEED);

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Status", cell, "text", Column.STATUS);

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Last", cell, "text", Column.LAST);

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Range", cell, "text", Column.RANGE);
			col = view.get_column(Column.RANGE);
			col.set_cell_data_func(cell, (col,_cell,model,iter) => {
					string s="";
					Value v;
					model.get_value(iter, Column.RANGE, out v);
					double rval = (double)v;
					model.get_value(iter, Column.SID, out v);
					string sid= (string)v;

					if(sid == "S" || sid == "A") {
						if (rval != TOTHEMOON) {
							s = Units.ga_range(rval);
						}
					} else if (rval != TOTHEMOON) {
						s = "%.0f %s".printf(Units.distance(rval), Units.distance_units());
					}
					_cell.set_property("text",s);
				});


			/**

			   ga_alt = Units.ga_alt(r.altitude);
			   ga_speed = Units.ga_speed(r.speed);
			   //			if (idm != TOTHEMOON) {
			   //	ga_range = Units.ga_range(idm);
			   //}
			   } else {
			   ga_alt = "%.0f %s".printf(Units.distance(r.altitude), Units.distance_units());
			   ga_speed = "%.0f %s".printf(Units.speed(r.speed), Units.speed_units());
			   //if (idm != TOTHEMOON) {
			   //	ga_range = "%.0f %s".printf(Units.distance(idm), Units.distance_units());
			   //}
			   }

			**/

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Brg.", cell, "text", Column.BEARING);

			cell = new Gtk.CellRendererText ();
			view.insert_column_with_attributes (-1, "Cat.", cell, "text", Column.CATEGORY);

			int [] widths = {2,12, 16, 16, 10, 10, 10, 12, 12, 12, 6, 4, 4};
			for (int j = Column.SID; j <= Column.CATEGORY; j++) {
				var scol =  view.get_column(j);
				if(scol!=null) {
					scol.set_min_width(7*widths[j]);
					scol.resizable = true;
					if (j == Column.SID || j == Column.NAME || j == Column.STATUS || j == Column.LAST || j == Column.RANGE)
						scol.set_sort_column_id(j);
				}
			}
		}
	}
}
