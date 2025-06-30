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

public class JoyReader {

	[Flags]
	public enum ChanType {
		INVERT,
		LATCH,
	}

	public struct ChanDef {
		int channel;
		int last;
		ChanType ctype;
		uint8 lval;
		uint8 lmax;
	}

	private const int INAV_CHAN_MAX=34;

	public ChanDef []axes;
	public ChanDef []buttons;
	public ChanDef []hats;
	public ChanDef []balls;

	private uint []channels;
	private bool fake;

	public int deadband;
	public int defval;

	public signal void update(int i, int v);

	public JoyReader(bool _fake=false) {
		fake = _fake;
		deadband = 0;
		defval = 0;
		reset_all();
	}

	public void set_sizes(int nax, int nbtn, int nba=0, int nhat=0) {
		//		if (nax > 0) {
			axes = new ChanDef[nax];
			//}
			//if (nbtn > 0) {
			buttons = new ChanDef[nbtn];
			//}
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
		if (ChanType.INVERT in axes[na].ctype) {
			cval = invert(cval);
		}
		set_channel(chn, cval);
	}

	public void set_button(int na, bool val) {
		var chn = buttons[na].channel;
		int cval;
		if(ChanType.LATCH in buttons[na].ctype) {
			if (!val) {
				if(get_channel(chn) == 0) {
					cval = 1000;
					if (ChanType.INVERT in buttons[na].ctype) {
						cval = invert(cval);
					}
					set_channel(chn, cval);
				}
				return;
			}
			buttons[na].lval = (buttons[na].lval+1) % buttons[na].lmax;
			cval = 1000 + 1000*buttons[na].lval/(buttons[na].lmax-1);
		} else {
			cval = (val) ? 2000 : 1000;
		}
		if (ChanType.INVERT in buttons[na].ctype) {
			cval = invert(cval);
		}
		set_channel(chn, cval);
	}

	public void dump_chandef() {
		int j =0;
		foreach(var a in axes) {
			if (a.channel != 0) {
				stderr.printf("Axis %d: channel %d, ctype %x, lval %u, lmax %u\n",
							  j, a.channel, a.ctype, a.lval, a.lmax);
			}
			j++;
		}
		j = 0;
		foreach(var b in buttons) {
			if (b.channel != 0) {
				stderr.printf("Button %d: channel %d, ctype %x, lval %u, lmax %u\n",
							  j, b.channel, b.ctype, b.lval, b.lmax);
			}
			j++;
		}
	}

	public void dump_channels(bool show=true) {
		string? []? chanset;
		chanset = new string[channels.length];
		int j =0;
		foreach(var a in axes) {
			if (a.channel != 0) {
				var s = " Axis %d".printf(j);
				if (chanset[a.channel-1] == null) {
					chanset[a.channel-1] = s;
				} else {
					chanset[a.channel-1] += s;
				}
			}
			j++;
		}
		j = 0;
		foreach(var b in buttons) {
			if (b.channel != 0) {
				var s = " Button %d".printf(j);
				if (chanset[b.channel-1] == null) {
					chanset[b.channel-1] = s;
				} else {
					chanset[b.channel-1] += s;
				}
			}
			j++;
		}
		j = 1;
		var ndef = false;
		foreach(var c in chanset) {
			StringBuilder sb = new StringBuilder();
			sb.append_printf("Channel %d", j);
			if(c == null) {
				sb.append_printf(" undefined (%d)", defval);
				ndef = true;
				channels[j-1] = defval;
			} else {
				sb.append(c);
			}
			sb.append_c('\n');
			if (show) {
				stderr.printf(sb.str);
			}
			j++;
		}
		if(ndef && show) {
			stderr.printf("\n*** Note: Undefined channels ***\n");
		}
	}

	public bool reader(string fn) {
		channels.resize(0);
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
						if(nc > 0 && nc <= INAV_CHAN_MAX) {
							if(nc > channels.length) {
								channels.resize(nc);
							}
							var extra = mi.fetch(4);
							ChanType ctype = 0;
							uint8 lmax = 2;
							if(extra != null) {
								var parts = extra.split(" ");
								foreach(var p in parts) {
									if (p == "invert") {
										ctype |= ChanType.INVERT;
									}
									if (p.has_prefix("latch")) {
										ctype |= ChanType.LATCH;
										int neql = p.index_of_char('=');
										if(neql != -1) {
											lmax = (uint8)uint.parse(p.substring(neql+1));
											lmax = uint8.max(lmax,2);
											lmax = uint8.min(lmax,6);
										}
									}
									if (p.has_prefix(";")  || p.has_prefix("#")) {
										break;
									}
								}
							}
							ChanDef chdef = {nc, 0, ctype, 0, lmax};

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
							case "default":
								var dbd = int.parse(parts[1].strip());
								if(dbd > 980 && dbd < 2100) {
									defval = dbd;
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
				dump_channels(true);
			}
		} catch (Error e) {
			stderr.printf("Err %s\n", e.message);
			ok = false;
		}
		return ok;
	}

	private uint8 check_range(int val, uint8 lmax, ChanType ct) {
		if(ChanType.INVERT in ct) {
			val = 3000 - val;
		}
		val -= 1000;

		for(var j = 0; j < lmax; j++) {
			var ival = 1000*j/lmax;
			var xval = 1000*(j+1)/lmax;
			if (val >= ival && val <= xval) {
				return j;
			}
		}
		if (val < 1000) {
			return 0;
		}
		return lmax-1;
	}

	public void init_channel(int chn, int val) {
		for (var j = 0; j < buttons.length; j++) {
			if (buttons[j].channel == 0)
				break;
			if (buttons[j].channel == chn && (ChanType.LATCH in buttons[j].ctype)) {
				buttons[j].lval = check_range(val, buttons[j].lmax, buttons[j].ctype);
				break;
			}
		}
		set_channel(chn, val);
	}

	public void set_channel(int j, int val) {
		update(j-1, val);
		AtomicUint.@set(ref channels[j-1], (int)(uint16)val);
	}

	public uint16 get_channel(int j) {
		uint16 val;
		val = (uint16)AtomicUint.@get(ref channels[j-1]);
		return val;
	}
	public uint16[] get_channels() {
		uint16 [] chans = new uint16[channels.length];
		for(var j = 0; j < channels.length; j++) {
			chans[j] = get_channel(j+1);
		}
		return chans;
	}

	public void reset_all() {
		if (channels == null || channels.length == 0) {
			channels.resize(16);
		}
		if(fake) {
			channels = {1500, 1500, 1000, 1500,
						1000, 1001, 1002, 1003,
						1004, 1005, 1006, 1007};
		} else {
			channels[0] = 1500;
			channels[1] = 1500;
			channels[2] = 999;
			channels[3] = 1500;
			for(var j = 4; j < channels.length; j++) {
				set_channel(j+1, 897);
			}
		}
	}

	public int normalise(int v) {
        double d = 1000.0*v/65535 + 1500;
        return (int)(d+0.5);
	}
}
