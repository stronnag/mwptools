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

	public struct LogData {
		uint index;
		uint16 length;
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

	public static LogData []? split_ublox(uint8[] dx) {
		var state = UState.HEADER1;
		uint16 len = 0;
		uint16 cnt = 0;
		uint8 cka = 0;
		uint8 ckb = 0;
		uint8 klass = 0;
		uint8 msgid = 0;
		LogData [] segs={};
		bool incl = false;
		uint8 da,mo=0;
		uint8 yr= 0;
		uint offset=0;

		var now = new DateTime.now_utc();

		for(var i = 0; i < dx.length;i++) {
			var d = dx[i];
			switch (state) {
			case UState.HEADER1:
				if (d == UPXProto.PREAMBLE1) {
					state = UState.HEADER2;
					incl = true;
					offset = i;
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
				klass = d;
				state = UState.ID;
				break;
			case UState.ID:
				ckb += (cka += d);
				msgid = d;
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
				if(klass == 0x13 && msgid == 0x20) {
					switch(cnt) {
					case 4:
						yr = d;
						break;
					case 5:
						mo = d;
						break;
					case 6:
						da = d;
						if(yr+2000 != now.get_year() || mo != now.get_month() || da != now.get_day_of_month()) {
							incl = false;
						}
						yr = 0;
						mo = 0;
						da = 0;
						break;
					default:
						break;
					}
				}
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
					if (incl) {
						var ld= LogData(){index=offset, length=len+8};
						segs += ld;
					}
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
		internal AssistNow.LogData []sg;
		internal int sid;

		internal static bool _close;

		private static GLib.Once<Window> _instance;
		public static unowned Window instance () {
			return _instance.once (() => { return new Window (); });
		}

		public signal void  gps_available(bool state);

		private static string assist_key;

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
						url = an.online_url(assist_key, useloc.active);
					} else {
						url = an.offline_url(assist_key);
					}
					id = get_file_base();
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
					sid = 0;
					Mwp.pause_poller(Mwp.SERSTATE.MISC_BULK);
					var str = get_file_base();
					MWPLog.message("Start Assist %s D/L\n", str);
					send_assist();
				});


			fileload.clicked.connect(() => {
					var id = get_file_base();
					var fn = get_cache_file(id);
					try {
						FileUtils.get_data(fn, out data);
						process_data(id, false);
					} catch {};
				});

			online.toggled.connect(_reset_label);
			offline.toggled.connect(_reset_label);

			this.gps_available.connect((b) => {
					apply.sensitive = b;
				});

			if(assist_key == "") {
				download.sensitive = false;
			}
		}

		public void init() {
			reset_labels();
			online.active = true;
			if(assist_key == null) {
				if(Mwp.conf.assist_key != "") {
					assist_key = Mwp.conf.assist_key;
				} else {
					Secret.Schema generic_schema =
						new Secret.Schema("org.freedesktop.Secret.Generic",
										  Secret.SchemaFlags.NONE,
										  "name", Secret.SchemaAttributeType.STRING,
										  "domain", Secret.SchemaAttributeType.STRING,
										  null
										  );
					var attributes = new GLib.HashTable<string,string> (str_hash, str_equal);
					attributes["name"] = "assist-key";
					attributes["domain"] = "org.stronnag.mwp";
					try {
						assist_key = Secret.password_lookupv_sync(generic_schema, attributes,  null);
					} catch (Error e) {
						MWPLog.message("libsecret: %s\n", e.message);
					}
				}
			}
		}

		string get_file_base() {
			return (online.active) ? "online" : "offline";
		}

		public void send_assist() {
			//MWPLog.message("Send check sid=%d sglen=%u\n", sid, sg.length);
			if (!_close && sid < sg.length) {
				var dlen = sg[sid].length;
				var offset = sg[sid].index;
				var dslice = data[offset:offset+dlen];
				//MWPLog.message("Send o=%u len=%u sid=%d\n", offset, dlen, sid);
				Mwp.queue_cmd(Msp.Cmds.INAV_GPS_UBLOX_COMMAND, dslice, dlen);
				sid++;
				format_astat(sid, sg.length);
			} else {
				MWPLog.message("Completed Assist D/L (%u)\n", sid);
				sid = -1;
				Mwp.reset_poller();
				if(assist_key != "") {
					download.sensitive = true;
				}
				apply.sensitive = check_apply();
			}
		}

		private bool check_apply() {
			return (Mwp.vi.fc_vers >= Mwp.FCVERS.hasAssistNow && Mwp.msp.available && ((Mwp.feature_mask &  Msp.Feature.GPS) != 0));
		}

		private void format_astat(int val, int vmax) {
			astat.label = " %4d / %4d".printf(val, vmax);
		}

		private void process_data(string id, bool docache) {
			asize.label = data.length.to_string();
			sg = AssistNow.split_ublox(data);
			if (sg.length > 0) {
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
			reset_labels();
		}

		private void reset_labels() {
			if(assist_key != "") {
				download.sensitive = true;
			}
			apply.sensitive = false;
			asize.label = "";
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
				var lnow = new  DateTime.now_utc();
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
