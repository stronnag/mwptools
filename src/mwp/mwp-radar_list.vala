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

	public enum Status {
		UNDEF = 0,
		ARMED = 1,
		HIDDEN = 2,
		STALE = 3,
	}

	public enum AStatus {
		C_MAP=1,
		C_GCS=2,
		C_HOME=3,
		C_VEHICLE=4,
		A_SOUND=8,
		A_TOAST=16,
		A_RED=32
	}

	public static AStatus astat;
	public static double lat;
	public static double lon;

	public static AStatus get_astatus() {
		astat = 0;
		bool haveloc = GCS.get_location(out lat, out lon); // always wins
		if (haveloc) {
			astat = C_GCS|A_SOUND|A_TOAST|A_RED;
		} else {
			if (Mwp.msp.available && Mwp.msp.td.gps.fix > 0) {
				astat = C_VEHICLE|A_SOUND|A_TOAST|A_RED;
				lat = Mwp.msp.td.gps.lat;
				lon = Mwp.msp.td.gps.lon;
			} else if(HomePoint.is_valid()) {
				haveloc = HomePoint.get_location(out lat, out lon);
				if (haveloc) {
					astat = C_HOME|A_RED;
				}
			}
		}
		if (astat == 0) {
			MapUtils.get_centre_location(out lat, out lon);
			astat = C_MAP;
		}
		return astat;
	}


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
			radarv.visible=false;
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

				} else if (pn.has_prefix("http://") ||
						   pn.has_prefix("https://") ||
						   pn.has_prefix("adsbx://") ) {
					uint8 htype = 0;
					if(pn.has_suffix(".pb")) {
						htype = 1;
					} else if(pn.has_suffix(".json")) {
						htype = 2;
					} else if (pn.has_prefix("adsbx://")) {
						htype = 3;
					}

					if(htype != 0) {
						MWPLog.message("Set up http radar device %s\n", pn);
						ADSBReader httpa;
						if(htype == 3) {
							httpa = new ADSBReader.adsbx(pn);
						} else  {
							httpa = new ADSBReader.web(pn);
						}
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
					r.dev.serial_event.connect(()  => {
							MWSerial.INAVEvent? m;
							while((m = r.dev.msgq.try_pop()) != null) {
								MspRadar.handle_radar(r.dev, m.cmd,m.raw,m.len,m.flags,m.err);
							}
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
			var r = radar_cache.get_item(i);
			if (r != null) {
				uint rk = r.id;
				var is_adsb = ((r.source & RadarSource.M_ADSB) != 0);
				var staled = 15*TimeSpan.SECOND;
				var hided = 30*TimeSpan.SECOND;;
				var deled = 60*TimeSpan.SECOND;
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
						r.state = Radar.Status.HIDDEN; // hidden
						r.alert = RadarAlert.SET;
						radar_cache.upsert(rk, r);
						radarv.update(rk, ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE));
						if (r.posvalid) {
							Radar.set_radar_hidden(rk);
						}
					}
				} else if(delta > staled) {
					if(rdebug)
						MWPLog.message("TRAF-STALE %X %s %u %u\n", rk, r.name, r.state, radar_cache.size());
					r.state = Radar.Status.STALE; // stale
					r.alert = RadarAlert.SET;
					radar_cache.upsert(rk, r);
					radarv.update(rk, ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE));
					if(r.posvalid) {
						Radar.set_radar_stale(rk);
					}
				} else {
					if(is_adsb) {
						r.state = 0;
						radar_cache.upsert(rk, r);
						radarv.update(rk, ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE));
					}
				}
			}
		}
	}

    private void try_radar_dev(RadarDev r) {
		if(!r.dev.available) {
			r.dev.open_async.begin(r.name, 0, (obj,res) => {
					var ok = r.dev.open_async.end(res);
					if (ok) {
						r.dev.setup_reader();
						MWPLog.message("start radar reader %s\n", r.name);
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
		Gtk.Button[] buttons;

		Gtk.ColumnView cv;
		Gtk.NoSelection lsel;

		bool vhidden;

		enum Buttons {
			CENTRE,
			HIDE,
			CLOSE
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

		public static string[] status = {"Undefined", "Armed", "Hidden", "Stale"};

		private void create_cv() {
			cv = new Gtk.ColumnView(null);
			var filterz = new Gtk.CustomFilter((o) => {
					if(Mwp.conf.max_radar_altitude > 0 &&
					   ((RadarPlot)o).altitude > Mwp.conf.max_radar_altitude) {
						return false;
					}
					return true;
				});

			var fm = new Gtk.FilterListModel (radar_cache.lstore, filterz);
			var sm = new Gtk.SortListModel(fm, cv.sorter);
			lsel = new Gtk.NoSelection(sm);
			cv.set_model(lsel);
			cv.show_column_separators = true;
			cv.show_row_separators = true;

			var f0 = new Gtk.SignalListItemFactory();
			var c0 = new Gtk.ColumnViewColumn("*", f0);
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = source_id(r.source);
					r.notify["source"].connect((s,p) => {
							label.label = source_id(((RadarPlot)s).source);
						});
				});
			var expression = new Gtk.PropertyExpression(typeof(RadarPlot), null, "source");
			c0.set_sorter(new Gtk.NumericSorter(expression));

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Name", f0);
			c0.expand = true;
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});

			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					r.bind_property("name", label, "label", BindingFlags.SYNC_CREATE);
					r.notify["alert"].connect((s,p) => {
							if(((( RadarPlot)s).alert & RadarAlert.ALERT) != 0 &&
							   (Radar.astat & Radar.AStatus.A_RED) == Radar.AStatus.A_RED) {
								label.add_css_class("error");
							} else {
								label.remove_css_class("error");
							}
						});
				});

			expression = new Gtk.PropertyExpression(typeof(RadarPlot), null, "name");
			c0.set_sorter(new Gtk.StringSorter(expression));

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Latitude", f0);
			cv.append_column(c0);
			c0.expand = true;
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = PosFormat.lat(r.latitude, Mwp.conf.dms);
					r.notify["latitude"].connect((s,p) => {
							label.label = PosFormat.lat(((RadarPlot)s).latitude, Mwp.conf.dms);
						});
				});
			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Longitude", f0);
			c0.expand = true;
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = PosFormat.lon(r.longitude, Mwp.conf.dms);
					r.notify["latitude"].connect((s,p) => {
							label.label = PosFormat.lon(((RadarPlot)s).longitude, Mwp.conf.dms);
						});
				});
			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Altitude", f0);
			c0.expand = true;
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = format_alt(r);
					r.notify["altitude"].connect((s,p) => {
							label.label = format_alt((RadarPlot)s);
						});
				});

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Course", f0);
			c0.expand = true;
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = format_course(r);
					r.notify["heading"].connect((s,p) => {
							label.label = format_course((RadarPlot)s);
						});
				});

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Speed", f0);
			c0.expand = true;
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = format_speed(r);
					r.notify["speed"].connect((s,p) => {
							label.label = format_speed((RadarPlot)s);
						});
				});

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Status", f0);
			cv.append_column(c0);
			expression = new Gtk.PropertyExpression(typeof(RadarPlot), null, "state");
			c0.set_sorter(new Gtk.NumericSorter(expression));
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);

				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = format_status(r);
					r.notify["state"].connect((s,p) => {
							label.label = format_status((RadarPlot)s);
						});
					r.notify["lq"].connect((s,p) => {
							label.label = format_status((RadarPlot)s);
						});
				});

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Last", f0);
			c0.expand = true;
			var dtsorter = new Gtk.CustomSorter((a,b) => {
					return (int)((RadarPlot)a).dt.difference(((RadarPlot)b).dt);
				});
			c0.set_sorter(dtsorter);
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = format_last(r);
					r.notify["dt"].connect((s,p) => {
							label.label = format_last((RadarPlot)s);
						});
				});

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Range", f0);
			c0.expand = true;
			cv.append_column(c0);
			expression = new Gtk.PropertyExpression(typeof(RadarPlot), null, "range");
			c0.set_sorter(new Gtk.NumericSorter(expression));

			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = format_range(r);
					r.notify["range"].connect((s,p) => {
							label.label = format_range((RadarPlot)s);
						});
				});

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Bearing", f0);
			c0.expand = true;
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = format_bearing(r);
					r.notify["bearing"].connect((s,p) => {
							label.label = format_bearing((RadarPlot)s);
						});
				});

			f0 = new Gtk.SignalListItemFactory();
			c0 = new Gtk.ColumnViewColumn("Cat", f0);
			c0.expand = true;
			cv.append_column(c0);
			expression = new Gtk.PropertyExpression(typeof(RadarPlot), null, "etype");
			c0.set_sorter(new Gtk.NumericSorter(expression));
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					RadarPlot r = list_item.get_item() as RadarPlot;
					var label = list_item.get_child() as Gtk.Label;
					label.label = format_cat(r);
					r.notify["etype"].connect((s,p) => {
							label.label = format_cat((RadarPlot)s);
						});
				});

			var clm = cv.get_columns();
			//               * Nm  La  Lo  Al  Cse Spd Sts Lst Rng Brg Cat
			//               0  1   2   3   4   5   6   7   8 , 9, 19, 11
			int [] widths = {0 ,10, 14, 15, 10, 9, 10, 15, 11, 11,  9, 6};
			for (var j = 0; j < clm.get_n_items(); j++) {
				if(widths[j] != 0) {
					var cw = clm.get_item(j) as Gtk.ColumnViewColumn;
					cw.set_fixed_width(7*widths[j]);
					cw.resizable = true;
				}
			}
		}

		private string format_cat(RadarPlot r) {
			if((r.source & RadarSource.M_INAV) != 0) {
				return "B6";
			}
			return CatMap.to_category(r.etype);
		}

		private string format_bearing(RadarPlot r) {
			string ga;
			if (r.bearing == 0xffff) {
				ga = "";
			} else {
				ga = "%u°".printf(r.bearing);
			}
			return ga;
		}

		private string format_range(RadarPlot r) {
			string ga = "";
			if (r.range != TOTHEMOON && r.range != 0.0) {
				if((r.source & RadarSource.M_ADSB) != 0) {
					ga = Units.ga_range(r.range);
				} else {
					ga = "%.0f %s".printf(Units.distance(r.range), Units.distance_units());
				}
			}
			return ga;
		}

		private string format_last(RadarPlot r) {
			if (r.dt != null) {
				return r.dt.format("%T");
			} else {
				return "";
			}
		}

		private string format_status(RadarPlot r) {
			string sstr = "";
			if(r.state == 0) {
				sstr = ((RadarSource)r.source).to_string();
			} else {
				sstr = RadarView.status[r.state];
			}
			return "%s / %u".printf(sstr, r.lq);
		}

		private string format_alt(RadarPlot r) {
			string ga;
			if((r.source & RadarSource.M_ADSB) != 0) {
				ga = Units.ga_alt(r.altitude);
			} else {
				ga = "%.0f %s".printf(Units.distance(r.altitude), Units.distance_units());
			}
			return ga;
		}

		private string format_speed(RadarPlot r) {
			string ga;
			if((r.source & RadarSource.M_ADSB) != 0) {
				ga = Units.ga_speed(r.speed);
			} else {
				ga = "%.0f %s".printf(Units.speed(r.speed), Units.speed_units());
			}
			return ga;
		}

		private string format_course(RadarPlot r) {
			string ga;
			if (r.heading ==  0xffff) {
				ga = "";
			} else {
				ga = "%u°".printf(r.heading);
			}
			return ga;
		}

		public RadarView () {
			set_transient_for(Mwp.window);
			vis = false;
			last_sec = 0;

			var sbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
			var header_bar = new Adw.HeaderBar();
			sbox.append(header_bar);
			var scrolled = new Gtk.ScrolledWindow ();
			set_default_size (900, 400);
			title = "Radar & Telemetry Tracking";
			label = new Gtk.Label ("");
			var grid = new Gtk.Grid ();
			create_cv();
			cv.hexpand = true;
			cv.vexpand = true;
			scrolled.propagate_natural_height = true;
			scrolled.propagate_natural_width = true;
			scrolled.set_child(cv);

			buttons = {
				new Gtk.Button.with_label ("Centre on swarm"),
				new Gtk.Button.with_label ("Hide symbols"),
				new Gtk.Button.with_label ("Close")
			};

			vhidden = false;

			buttons[Buttons.HIDE].clicked.connect (() => {
					if(!vhidden) {
						buttons[Buttons.HIDE].label = "Show symbols";
						Gis.rm_layer.set_visible(false);
					} else {
						buttons[Buttons.HIDE].label = "Hide symbols";
						Gis.rm_layer.set_visible(true);
					}
					vhidden = !vhidden;
				});

			buttons[Buttons.CLOSE].clicked.connect (() => {
					visible=false;
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
					visible=false;
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
			case RadarSource.ADSBX:
				return "X";
			}
			return "?";
		}

		private void zoom_to_swarm() {
			int n = 0;
			double alat = 0;
			double alon = 0;

			for(var j = 0; j < Radar.radar_cache.size(); j++) {
				var r = Radar.radar_cache.get_item(j) as RadarPlot;
				alat += r.latitude;
				alon += r.longitude;
				n++;
			}
			if(n != 0) {
				alat /= n;
				alon /= n;
				MapUtils.centre_on(alat, alon);
			}
		}

		private void show_number() {
			uint n_rows = Radar.radar_cache.size();
			uint stale = 0;
			uint hidden = 0;

			buttons[Buttons.CENTRE].sensitive = (n_rows != 0);

			for(var j = 0; j < n_rows; j++) {
				var r = Radar.radar_cache.get_item(j);
				if(r.state == Radar.Status.STALE) {
					stale++;
				} else if(r.state == Radar.Status.HIDDEN)
					hidden++;
			}
			var sb = new StringBuilder("Targets: ");
			uint live = n_rows - stale - hidden;
			sb.append_printf("%u", n_rows);
			if (live > 0 && (stale+hidden) > 0)
				sb.append_printf("\tLive: %u", live);
			if (stale > 0)
				sb.append_printf("\tStale: %u", stale);
			if (hidden > 0)
				sb.append_printf("\tHidden: %u", hidden);

			label.set_text (sb.str);
		}

		public void remove (uint rid) {
			var found = Radar.radar_cache.remove (rid);
			if (found) {
				show_number();
			} else {
				MWPLog.message("Radar view failed for %X\n", rid);
			}
		}

		public void update (uint rk, bool verbose = false) {
			var dt = new DateTime.now_local ();
			double idm = TOTHEMOON;
			double hlat, hlon;

			var r = Radar.radar_cache.lookup(rk);
			if (r == null)
				return;

			var alert = r.alert;
			var xalert = r.alert;
			bool havehome = false;
			havehome =  GCS.get_location(out hlat, out hlon);
			if (!havehome) {
				if(HomePoint.is_valid()) {
					havehome = HomePoint.get_location(out hlat, out hlon);
				}
			}
			if(havehome) {
				double c,d;
				Geo.csedist(hlat, hlon, r.latitude, r.longitude, out d, out c);
				idm = d*1852.0; // nm to m
				r.range = idm;
				r.bearing = (uint16)c;
			} else {
				if(r.srange != 0xffffffff) {
					r.range = (double)(r.srange);
				}
				r.bearing = 0xffff;
			}

			if(!vhidden && (r.source & RadarSource.M_ADSB) != 0 && r.bearing != 0xffff) {
				if(Mwp.conf.radar_alert_altitude > 0 && Mwp.conf.radar_alert_range > 0 &&
				   r.altitude < Mwp.conf.radar_alert_altitude && r.range < Mwp.conf.radar_alert_range) {
					xalert = RadarAlert.ALERT;
					var this_sec = dt.to_unix();
					if(r.state < Radar.Status.STALE && this_sec >= last_sec + 2) {
						last_sec =  this_sec;
						if(( Radar.astat & Radar.AStatus.A_TOAST) == Radar.AStatus.A_TOAST) {
							string s = "ADSB proximity %s %s@%s \u21d5%s".printf(r.name, format_range(r), format_bearing(r), format_alt(r));
							if(r.extra == null) {
								r.extra = Mwp.add_toast_text(s, 0);
								((Adw.Toast)r.extra).dismissed.connect(() => {
										r.extra = null;
									});
							} else {
								if (r.extra != null) {
									((Adw.Toast)r.extra).set_title(s);
								}
							}
						}

						if(( Radar.astat & Radar.AStatus.A_SOUND) == Radar.AStatus.A_SOUND) {
							Audio.play_alarm_sound(MWPAlert.GENERAL);
						}
					}
				} else {
					xalert = RadarAlert.NONE;
					if (r.extra != null) {
						((Adw.Toast)r.extra).dismiss();
					}
				}
			}
			if (alert != xalert) {
				xalert |= RadarAlert.SET;
				r.alert = xalert;
			}
			if(r.state >= RadarView.status.length)
				r.state = Status.UNDEF;
			show_number();
		}
	}
}
/*
  MWPLog.message(":DBG:RADAR Check %s range:%u bearing:%u alt:%.0f (r=%u a=%u)\n",
  r.name, (uint)r.range, r.bearing, r.altitude,
  Mwp.conf.radar_alert_range, Mwp.conf.radar_alert_altitude);
*/