public class JoyReader {
	public struct ChanDef {
		int channel;
		int last;
		bool invert;
		bool? latch;
	}

	public ChanDef []axes;
	public ChanDef []buttons;
	public ChanDef []hats;
	public ChanDef []balls;

	private uint16 channels[16];
	private bool fake;

	public int deadband;

	public JoyReader(bool _fake=false) {
		fake = _fake;
		deadband = 0;
		reset_all();
	}

	public void set_sizes(int nax, int nbtn, int nba=0, int nhat=0) {
		if (nax > 0) {
			axes = new ChanDef[nax];
		}
		if (nbtn > 0) {
			buttons = new ChanDef[nbtn];
		}
		if (nba > 0){
			balls = new ChanDef[nba];
		}
		if (nhat > 0) {
			hats = new ChanDef[nhat];
		}
	}

	private int invert(int v) {
		return 3000 - v;
	}

	public void set_axis(int na, int16 val) {
		var chn = axes[na].channel;
		int cval = normalise(val);
		if (axes[na].invert) {
			cval = invert(cval);
		}
		set_channel(chn, cval);
	}

	public void set_button(int na, bool val) {
		var chn = buttons[na].channel;
		int cval;
		if (buttons[na].latch != null) {  
			if (val) { 
				buttons[na].latch = (buttons[na].latch == true) ? false : true;
			} 
			val = buttons[na].latch ?? false;
		} 
		if (buttons[na].invert) {
			cval = (val) ? 1000 : 2000;
		} else {
			cval = (val) ? 2000 : 1000;
		}
		set_channel(chn, cval);
	}

	public bool reader(string fn) {
		bool ok = false;
		var rs = """^(\S+)\s+(\d+)\s+=\s+Channel\s+(\d+)\s+(\S?.*)""";
		try {
			var rx = new Regex(rs, 0, 0);
			var dis = FileStream.open(fn,"r");
			if(dis != null) {
				ok = true;
				int maxnc = 0;
				string line=null;
				while ((line = dis.read_line ()) != null) {
					line = line.strip();
					if(line.length == 0 || line.has_prefix("#") || line.has_prefix(";")) {
						continue;
					}
					var icmt = line.index_of(";");
					if (icmt == -1)  {
						icmt = line.index_of("#");
					}
					if (icmt > 0) {
						line = line[:icmt];
					}
					MatchInfo mi;
					uint nf;
					int nc = 0;
					if(rx.match(line, 0, out mi)) {
						nf = uint.parse(mi.fetch(2));
						nc = int.parse(mi.fetch(3));
						if(nc > 0 && nc < 17) {
							var extra = mi.fetch(4);
							bool invert = false;
							bool? latch = null;
							if(extra != null) {
								var parts = extra.split(" ");
								foreach(var p in parts) {
									if (p == "invert") {
										invert = true;
										break;
									}
									if (p == "latch") {
										latch = false;
										break;
									}
								}
							}
							ChanDef chdef = {nc, 0, invert, latch};

							switch(mi.fetch(1)) {
							case "Axis":
								axes[nf] = chdef;
								break;
							case "Ball":
								balls[nf] = chdef;
								break;
							case "Button":
								buttons[nf] = chdef;
								break;
							case "Hat":
								hats[nf] = chdef;
								break;
							default:
								ok = false;
								break;
							}
						} else {
							stderr.printf("Channel error %s\n", line);
							ok = false;
						}
					} else {
						var parts = line.split("=");
						if (parts.length == 2) {
							switch (parts[0].strip()) {
							case "deadband":
								var dbd = int.parse(parts[1].strip());
								if(dbd > 0 && dbd < 1024) {
									deadband = dbd;
								}
								break;
							default:
								break;
							}
						}
					}
					if (!ok) {
						break;
					}
					if (nc > maxnc) {
						maxnc = nc;
					}
				}
				for (var j = maxnc; j < 16; j++) {
					channels[j] = 1500;
				}
			}
		} catch (Error e) {
			print("Err %s\n", e.message);
			ok = false;
		}
		return ok;
	}

	public void set_channel(int j, int val) {
		lock(channels) {
			channels[j-1] = (uint16)val;
		}
		unlock(channels);
	}

	public uint16 get_channel(int j) {
		uint16 val;
		lock(channels) {
			val = channels[j-1];
		}
		unlock(channels);
		return val;
	}
	public uint16[] get_channels() {
		uint16 [] chans;
		lock(channels) {
			chans = channels;
		}
		unlock(channels);
		return chans;
	}

	public void reset_all() {
		lock(channels) {
			if(fake) {
				channels = {1500, 1500, 1000, 1500,
					1000, 1001, 1002, 1003,
					1004, 1005, 1006, 1007,
					1009, 1010, 1011, 1012};
			} else {
				for(var j = 0; j < 16; j++) {
					channels[j] = 897;
				}
			}
		}
		unlock(channels);
	}

	public int normalise(int v) {
        double d = 1000.0*v/65535 + 1500;
        return (int)(d+0.5);
	}
}
