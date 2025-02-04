public class AssistNow {
	private enum UState {
		HEADER1,
		HEADER2,
		CLASS,
		ID,
		LENLO,
		LENHI,
		DATA,
		CHKA,
		CHKB
	}

	private enum UPXProto {
		PREAMBLE1 = 0xb5,
		PREAMBLE2 = 0x62
	}

	private Soup.Session session;
	public AssistNow () {
		session = new Soup.Session ();
	}

	public string online_url(string token, bool useloc) {
		StringBuilder sb = new StringBuilder("https://online-live1.services.u-blox.com/GetOnlineData.ashx?token=");
		sb.append(token);
		sb.append("&gnss=gps,gal,bds,glo,qzss&datatype=eph,alm,aux,pos&format=mga");
		if(useloc) {
			double lat,lon;
			if(HomePoint.is_valid()) {
				HomePoint.get_location(out lat, out lon);
			} else {
				MapUtils.get_centre_location(out lat, out lon);
			}
			sb.append_printf("&lat=%f&lon=%f&filteronpos", lat, lon);
		}
		return sb.str;
	}

	public string offline_url(string token) {
		StringBuilder sb = new StringBuilder("https://offline-live1.services.u-blox.com/GetOfflineData.ashx?token=");
		sb.append(token);
		sb.append("&gnss=gps,gal,bds,glo&format=mga&period=5&resolution=1&alm=gps,qzss,gal,bds,glo");
		return sb.str;
	}

	public async uint8[]? fetch(string uri) {
		Soup.Message msg;
		msg = new Soup.Message ("GET", uri);
		try {
			var byt = yield session.send_and_read_async (msg, Priority.DEFAULT, null);
			if (msg.status_code == 200) {
				return byt.get_data();
			} else {
				MWPLog.message("UBLOX fetch <%s> : %u %s\n", uri, msg.status_code, msg.reason_phrase);
				return null;
			}
		} catch (Error e) {
			print("UBLOX fetch <%s> : %s\n", uri, e.message);
			return null;
		}
	}

	public static uint16 []? split_ublox(uint8[] dx) {
		var state = UState.HEADER1;
		uint16 len = 0;
		uint16 cnt = 0;
		uint8 cka = 0;
		uint8 ckb = 0;
		uint16 [] segs={};

		foreach (var d in dx) {
			switch (state) {
			case UState.HEADER1:
				if (d == UPXProto.PREAMBLE1) {
					state = UState.HEADER2;
				}
				break;
			case UState.HEADER2:
				if (d == UPXProto.PREAMBLE2) {
					state = UState.CLASS;
				} else {
					state = UState.HEADER1;
				}
				break;
			case UState.CLASS:
				ckb = cka = d;
				state = UState.ID;
				break;
			case UState.ID:
				ckb += (cka += d);
				state = UState.LENLO;
				break;
			case UState.LENLO:
				ckb += (cka += d);
				len = d;
				state = UState.LENHI;
				break;
			case UState.LENHI:
				ckb += (cka += d);
				len += (uint16)(d<<8);
				cnt = 0;
				state = UState.DATA;
				break;
			case UState.DATA:
				ckb += (cka += d);
				cnt ++;
				if (cnt == len) {
					state = UState.CHKA;
				}
				break;
			case UState.CHKA:
				if (d == cka) {
					state = UState.CHKB;
				} else {
					state = UState.HEADER1;
					MWPLog.message("UBlox Assist: Check A fails\n");
					return null;
				}
				break;
			case UState.CHKB:
				if (d == ckb) {
					segs += (len+8);
				} else {
					MWPLog.message("UBlox Assist: Check B fails\n");
					return null;
				}
				state = UState.HEADER1;
				break;
			}
		}
		return segs;
	}
}

namespace Assist {
	[GtkTemplate (ui = "/org/stronnag/mwp/assistnow.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		internal unowned Gtk.Button fileload;
		[GtkChild]
		internal unowned Gtk.Button download;
		[GtkChild]
		internal unowned Gtk.Button apply;
		[GtkChild]
		internal unowned Gtk.CheckButton online;
		[GtkChild]
		internal unowned Gtk.CheckButton offline;
		[GtkChild]
		internal unowned Gtk.CheckButton useloc;

		[GtkChild]
		internal unowned Gtk.Label asize;
		[GtkChild]
		internal unowned Gtk.Label astat;

		internal AssistNow? an;
		internal uint8 []data;
		internal uint16 []sg;
		internal uint offset;
		internal int sid;
		internal int sidtx;
		internal DateTime now;
		internal int nfilt;

		internal static bool _close;

		private static GLib.Once<Window> _instance;
		public static unowned Window instance () {
			return _instance.once (() => { return new Window (); });
		}

		public signal void  gps_available(bool state);

		public Window() {
			_close = false;
			transient_for = Mwp.window;
			close_request.connect(() => {
					_close = true;
					visible = false;
					return true;
				});

			an = null;

			download.clicked.connect(() => {
					an = new AssistNow();
					string url;
					string id;

					if (online.active) {
						url = an.online_url(Mwp.conf.assist_key, useloc.active);
					} else {
						url = an.offline_url(Mwp.conf.assist_key);
					}
					id = get_file_base();
					nfilt = 0;
					an.fetch.begin(url, (obj, res) => {
							data = an.fetch.end(res);
							if (data != null) {
								process_data(id, true);
							} else {
								asize.label = "D/L Error!";
							}
						});
				});

			apply.clicked.connect(() => {
					apply.sensitive = false;
					download.sensitive = false;
					offset = 0;
					sid = 0;
					sidtx = 0;
					Mwp.pause_poller(Mwp.SERSTATE.MISC_BULK);
					var str = get_file_base();
					MWPLog.message("Start Assist %s D/L\n", str);
					send_assist();
				});


			fileload.clicked.connect(() => {
					nfilt = 0;
					var id = get_file_base();
					var fn = get_cache_file(id);
					try {
						FileUtils.get_data(fn, out data);
						process_data(id, false);
					} catch {};
				});

			online.toggled.connect(_reset_label);
			offline.toggled.connect(_reset_label);

			online.active = true;
			now = new DateTime.now_utc();
			this.gps_available.connect((b) => {
					apply.sensitive = b;
				});

			if(Mwp.conf.assist_key == "") {
				download.sensitive = false;
			}
		}

		string get_file_base() {
			return (online.active) ? "online" : "offline";
		}

		private const int PAYOFF = 6;

		private bool filter_data(uint8[]dx) {
			var cls = dx[2];
			var mid = dx[3];
			if(cls == 0x13 && mid == 0x20) {
				uint8 yr = dx[PAYOFF+4];
				uint8 mo = dx[PAYOFF+5];
				uint8 da = dx[PAYOFF+6];
				var fdt = new DateTime.utc(yr+2000, mo, da, 12, 0, 0.0);
				var tdiff = now.difference(fdt);
				if(tdiff < -12*TimeSpan.HOUR || tdiff > 12*TimeSpan.HOUR) {
					return true;
				}
			}
			return false;
		}

		public void send_assist() {
			if (!_close && sid < sg.length) {
				var dlen = sg[sid];
				var dslice = data[offset:offset+dlen];
				var filtered = filter_data(dslice);
				if (!filtered) {
					Mwp.queue_cmd(Msp.Cmds.INAV_GPS_UBLOX_COMMAND, dslice, dlen);
					sidtx++;
				}
				sid++;
				format_astat(sidtx, sg.length);
				offset += dlen;
			} else {
				MWPLog.message("Completed Assist D/L\n");
				sid = -1;
				Mwp.reset_poller();
				if(Mwp.conf.assist_key != "") {
					download.sensitive = true;
				}
				apply.sensitive = check_apply();
			}
		}

		private bool check_apply() {
			return (Mwp.msp.available && ((Mwp.feature_mask &  Msp.Feature.GPS) != 0));
		}

		private void format_astat(int val, int vmax) {
			if(nfilt == 0) {
				astat.label = " %4d / %4d".printf(val, vmax);
			} else {
				astat.label = " %4d / %4d [%4d]".printf(val, vmax-nfilt, vmax);
			}
		}

		private void process_data(string id, bool docache) {
			asize.label = data.length.to_string();
			sg = AssistNow.split_ublox(data);
			if (sg.length > 0) {
				int o = 0;
				foreach(var g in sg) {
					var dslice = data[o:o+g];
					var filtered = filter_data(dslice);
					if (filtered) {
						nfilt++;
					}
					o += g;
				}
				format_astat(0, sg.length);
				apply.sensitive = check_apply();
				if(docache) {
					var fn =  get_cache_file(id);
					try {
						FileUtils.set_data(fn, data);
						fileload.sensitive  = true;
					} catch {}
				}
			}
		}

		private void _reset_label(Gtk.CheckButton b) {
			if (b.active) {
				fileload.sensitive =  check_cached(get_file_base());
			}
			if(Mwp.conf.assist_key != "") {
				download.sensitive = true;
			}
			apply.sensitive = false;
			asize.label = "tbd";
			nfilt = 0;
			format_astat(0,0);
		}

		public void show_error() {
			Mwp.reset_poller();
			download.sensitive = false;
			astat.label = "MSP Error!";
		}

		private string? get_cache_file(string id) {
			var cdir = Environment.get_user_cache_dir();
			var pb =  new PathBuf.from_path(cdir);
			pb.push("mwp");
			pb.push(id);
			pb.set_extension("ubx");
			return pb.to_path();
		}

		private bool check_cached(string id) {
			var ok = false;
			var fn = get_cache_file(id);
			File file = File.new_for_path (fn);
			try {
				var info =  file.query_info("*", FileQueryInfoFlags.NONE);
				var ctd = info.get_creation_date_time();
				var lnow = new  DateTime.now_local();
				TimeSpan ts;
				if(id == "online") {
					ts = TimeSpan.HOUR*4;
				} else {
					ts = TimeSpan.DAY*35;
				}
				ok = (lnow.difference(ctd) < ts);

			} catch {}
			return ok;
		}
	}
}
