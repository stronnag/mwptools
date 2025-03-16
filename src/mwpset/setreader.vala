public class XReader : Object {
	private Xml.Doc* doc;

	public struct Edata {
		string k;
		string v;
	}

	public struct EnumEntry {
		string id;
		Array<Edata?> eset;
		public EnumEntry() {
			eset = new Array<Edata?>();
		}
	}

	public struct KeyEntry {
		public string name;
		public string type;
		public EnumEntry? _enum;
		public string _default;
		public Array<string>? choices;
		public string summary;
		public string description;
		public string min;
		public string max;
		public Variant value;
		public bool is_changed;

		public KeyEntry() {
			is_changed = false;
		}
	}

	public struct Schema {
		public string id;
		public string path;
	}

	public GenericArray<KeyEntry?> keys;
	public GenericArray<EnumEntry?> enums;
	public Settings settings;

	private Schema schema;

	public static bool e_search (EnumEntry? a, string b) {
		return (b == a.id);
	}

	public static bool k_search (KeyEntry? a, string b) {
		return (b == a.name);
	}

	public XReader(string schm) {
		if (schm == null) {
			schm = "org.stronnag.mwp";
		}
		string s=null;
		var uc =  Environment.get_user_data_dir();
		var basefn = string.join("", schm, ".gschema.xml");
		var fn = Path.build_filename(uc,"glib-2.0", "schemas", basefn);
		try  {
			FileUtils.get_contents(fn, out s);
		} catch (FileError e) {
			stderr.printf("open: %s\n", e.message);
			var ucs = Environment.get_system_data_dirs();
			foreach (var _uc in ucs) {
				fn = Path.build_filename(_uc,"glib-2.0", "schemas", basefn);
				try  {
					FileUtils.get_contents(fn, out s);
					break;
				} catch (FileError e) {
					stderr.printf("open: %s\n", e.message);
				}
			}
		}
		if (s != null) {
			Xml.Parser.init();
			doc = Xml.Parser.parse_memory(s, s.length);
#if DARWIN
			uc =  Environment.get_user_config_dir();
			string kfile = GLib.Path.build_filename(uc,"mwp");
			DirUtils.create_with_parents(kfile, 0755);
			kfile = GLib.Path.build_filename(kfile , "mwp.ini");
			if(!FileUtils.test(kfile, FileTest.EXISTS|FileTest.IS_REGULAR)) {
				bool ok = false;
				var ud =  Environment.get_user_data_dir();
				var sds =  Environment.get_system_data_dirs();
				fn =  GLib.Path.build_filename(ud, "mwp", "mwp.ini");
				if (!FileUtils.test(fn, FileTest.EXISTS|FileTest.IS_REGULAR)) {
					foreach (var sd in sds) {
						fn =  GLib.Path.build_filename(sd, "mwp", "mwp.ini");
						if (FileUtils.test(fn, FileTest.EXISTS|FileTest.IS_REGULAR)) {
							ok = true;
							break;
						}
					}
				} else {
					ok = true;
				}
				if(ok) {
					string defset;
					try {
						if(FileUtils.get_contents(fn, out defset)) {
							FileUtils.set_contents(kfile, defset);
						}
					} catch (Error e) {
						stderr.printf("Copy settings: %s\n", e.message);
					}
			}
			}
			stderr.printf("Using settings keyfile %s\n", kfile);
			SettingsBackend kbe = SettingsBackend.keyfile_settings_backend_new(kfile, "/org/stronnag/mwp/","mwp");
			settings = new Settings.with_backend(schm, kbe);
#else
			stderr.printf("Using settings schema %s\n", schm);
			settings =  new Settings (schm);
#endif
		}
	}

	public void parse_schema() {
		if (doc == null) {
			return;
		}
		enums = new GenericArray<EnumEntry?>();
		keys = new GenericArray<KeyEntry?>();

		Xml.Node* root = doc->get_root_element ();
		if (root != null) {
			if (root->name == "schemalist") {
				for (Xml.Node* node = root->children; node != null; node = node->next) {
					if (node->type != Xml.ElementType.ELEMENT_NODE)
						continue;
					if (node->name.down() == "enum") {
						var e = EnumEntry(){};
						e.id = node->get_prop("id");
						for (Xml.Node* enode = node->children; enode != null; enode = enode->next) {
							if (enode->name.down() == "value") {
								var eval = Edata(){};
								eval.k = enode->get_prop("nick");
								eval.v = enode->get_prop("value");
								e.eset.append_val(eval);
							}
						}
						enums.add(e);
					} else {
						if (node->name.down() == "schema") {
							schema = Schema(){};
							schema.id = node->get_prop("id");
							schema.path = node->get_prop("path");

							for (Xml.Node* snode = node->children; snode != null; snode = snode->next) {
								if(snode->name.down() == "key") {
									var k = KeyEntry(){};
									k.name = snode->get_prop("name");
									k.type = snode->get_prop("type");
									var ename = snode->get_prop("enum");
									if(ename != null) {
										uint idx=0;
										enums.find_custom(ename, (ArraySearchFunc)e_search, out idx);
										k._enum = enums.@get(idx);
									}
									for (Xml.Node* knode = snode->children; knode != null; knode = knode->next) {
										switch(knode->name.down()) {
										case "default":
											var dstr = knode->get_content();
											if (k.type == "d") {
												var dbl = DStr.strtod(dstr, null);
												k._default = "%.8g".printf(dbl);
											} else {
												k._default = dstr;
											}
											break;
										case "summary":
											var ks = knode->get_content();
											k.summary = clean_string(ks);
											break;
										case "description":
											var kd = knode->get_content();
											k.description = clean_string(kd);
											break;
										case "range":
											k.min = knode->get_prop("min");
											k.max = knode->get_prop("max");
											break;
										case "choices":
											k.choices = new Array<string>();
											for (Xml.Node* cnode = knode->children; cnode != null; cnode = cnode->next) {
												if(cnode->name == "choice") {
													k.choices.append_val(cnode->get_prop("value"));
												}
											}
											break;
										}
									}

									k.value = settings.get_value(k.name);
									if(k.type == "b") {
										k.choices = new Array<string>();
										k.choices.append_val("false");
										k.choices.append_val("true");
									}
									if(!k.summary.has_prefix("Internal setting")) {
										keys.add(k);
									}
								}
							}
						}
					}
				}
			}
		}

		keys.sort_with_data((a,b) => {
				return strcmp(a.name, b.name);
			});
		return;
	}

	public static string clean_string(string kd) {
		string s = null;
		try {
			var regex = new Regex ("\\s+", RegexCompileFlags.MULTILINE);
			s = regex.replace(kd, kd.length, 0, " ");
		} catch (Error e) {
			stderr.printf("Regex: %s\n", e.message);
		}
		s = s.strip();
		return s;
	}

    public static string normalise(string s) {
		var n = s.length;
		if (n > 1 && ((s[0] == '"' && s[n-1] == '"') || (s[0] == '\'' && s[n-1] == '\''))) {
			return s.substring(1, n-2);
		} else {
			return s;
		}
	}

	public static string? format_variant(KeyEntry k) {
		string rs=null;
		if (k.type == "d") {
			var d = k.value.get_double();
			rs = "%.10g".printf(d);
		} else if (k.type != null) {
			rs = normalise(k.value.print(false));
		} else if (k._enum != null) {
			rs = k.value.get_string();
		} else {
			rs = "**FIXME**";
		}
		return rs;
	}
}
