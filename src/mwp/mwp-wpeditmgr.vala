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

namespace EditWP {
	[Flags]
	private enum EIFields {
		NO,
		P1,
		P2,
		P3,
		ALT,
		JUMP1,
		JUMP2,
		HDR,
		RTL,
		ACT,
		FLAG,
		OPT
	}

	private EditItem create(int no, out string posit) {
		EditItem ei ={};
		MissionItem mi;
		mi = MissionManager.current().points[no-1];
		ei.action = mi.action;
		ei.no = mi.no;
		posit = PosFormat.pos(mi.lat, mi.lon, Mwp.conf.dms, true);
		ei.alt = mi.alt;
		ei.p1 = (double)mi.param1;
		ei.p2 = (double)mi.param2;
        if(mi.action == Msp.Action.WAYPOINT || mi.action == Msp.Action.LAND) {
            ei.p1 /= 100.0; // FIXME (SPEED_CONV
        }
        if(mi.action == Msp.Action.POSHOLD_TIME) {
            ei.p2 /= 100.0;
		}
		ei.p3 = (int)mi.param3;
		ei.flag  = mi.flag;
		ei.elv = MsnTools.resolve_elevations(mi);
		ei.optional = 0;
		if ((mi._mflag & MsnTools.IFlags.RTH) != 0) {
			ei.optional |= WPEditMask.RTH;
		}
		if ((mi._mflag & MsnTools.IFlags.JUMPF) != 0) {
			ei.optional |= WPEditMask.JUMP;
			int _p1, _p2;
			if(get_extra(mi.no, Msp.Action.JUMP, out _p1, out _p2)) {
				ei.jump1 = _p1;
				ei.jump2 = _p2;
			}
		}
		if ((mi._mflag & MsnTools.IFlags.SET_HEAD) != 0) {
			ei.optional |= WPEditMask.SETHEAD;
			int _p1, _p2;
			if(get_extra(mi.no, Msp.Action.SET_HEAD, out _p1, out _p2)) {
				ei.heading = _p1;
			}
		}
		return ei;
	}

	private bool get_extra(int idx, Msp.Action act, out int p1, out int p2) {
		p1 = 0;
		p2 = 0;
		var m = MissionManager.current();
		for(var j = idx; j < m.npoints; j++) {
			if (m.points[j].action == act) {
				p1 = m.points[j].param1;
				p2 = m.points[j].param2;
				return true;
			}
		}
		return false;
	}

	private bool extract(int no, EditItem ei, EditItem orig) {
		bool ret = true;
		MissionItem mi;
		var ms = MissionManager.current();
		var idx = ms.get_index(no);

		mi = ms.points[idx];
		mi.action = ei.action;
		mi.alt = ei.alt;
		mi.flag  = ei.flag;
		mi.param3 = ei.p3;
        if(mi.action == Msp.Action.WAYPOINT || mi.action == Msp.Action.LAND) {
            mi.param1 = (int)(ei.p1*100.0); // FIXME (SPEED_CONV
        } else {
			mi.param1 = (int)ei.p1;
		}
        if(mi.action == Msp.Action.POSHOLD_TIME) {
            mi.param2 = (int)(ei.p2*100.0);
		} else {
			mi.param2 = (int)ei.p2;
		}

        if(mi.action == Msp.Action.SET_POI) {
			if ((ei.optional & WPEditMask.ATHOME) != 0) {
				double hlat, hlon;
				HomePoint.get_location(out hlat, out hlon);
				ms.points[idx].lat = hlat;
				ms.points[idx].lon = hlon;
			}
		}

		var wanted = -1;
		var emask = (ei.optional & WPEditMask.SETHEAD);
		var omask = (orig.optional & WPEditMask.SETHEAD);
		if (emask != omask) {
			if(emask != 0) { // add SETHEAD
				wanted = insert_element(idx, Msp.Action.SET_HEAD);
			} else { // remove SH
				remove_element(idx, Msp.Action.SET_HEAD);
			}
		} else {
			wanted = find_next(idx, Msp.Action.SET_HEAD);
		}
		if (wanted != -1) {
			ms.points[wanted].param1 = ei.heading;
		}

		wanted = -1;
		emask = (ei.optional & WPEditMask.JUMP);
		omask = (orig.optional & WPEditMask.JUMP);
		if (emask != omask) {
			if(emask != 0) { // added JUMP
				int valmax = (int)ms.npoints;
				var jok = validate_jump(no, ei.jump1, valmax);
				if(jok) {
					wanted = insert_element(idx, Msp.Action.JUMP);
					if(ei.jump1 > no) {
						ei.jump1++;
					}
				} else {
					ret = false;
				}
			} else { // removed JUMP
				remove_element(idx, Msp.Action.JUMP);
			}
		} else {
			wanted = find_next(idx, Msp.Action.JUMP);
			var jok = validate_jump(idx, ei.jump1, (int)ms.npoints);
			if(!jok) {
				ret = false;
				wanted = -1;
			}
		}
		if(wanted != -1) {
			ms.points[wanted].param1 = ei.jump1;
			ms.points[wanted].param2 = ei.jump2;
		}
		wanted = -1;
		emask = (ei.optional & WPEditMask.RTH);
		omask = (orig.optional & WPEditMask.RTH);
		if (emask != omask) {
			if(emask != 0) { // added RTH
				wanted = insert_element(idx, Msp.Action.RTH);
			} else { // removed RTH
				remove_element(idx, Msp.Action.RTH);
			}
		} else {
			wanted = find_next(idx, Msp.Action.RTH);
		}
		if(wanted != -1) {
			ms.points[wanted].param1 = ei.rthland;
		}
		return ret;
	}

	private bool validate_jump(int src, int dst, int lastid) {
		bool jok = false;

		jok =  !(dst < 1 || ((dst > src-2) && (dst < src+2)) || (dst > lastid));
		if(jok) {
			var m = MissionManager.current();
			jok = m.points[dst-1].is_geo();
		}
		return jok;
	}

	private EIFields eicmp(EditItem ei, EditItem xi) {
		EIFields res = 0;
		if(ei.no != xi.no) {
			res |= EIFields.NO;
		}
		if(ei.p1 != xi.p1) {
			res |= EIFields.P1;
		}
		if(ei.p2 != xi.p2) {
			res |= EIFields.P2;
		}
		if(ei.alt != xi.alt) {
			res |= EIFields.ALT;
		}
		if(ei.jump1 != xi.jump1) {
			res |= EIFields.JUMP1;
		}
		if(ei.jump2 != xi.jump2) {
			res |= EIFields.JUMP2;
		}
		if(ei.heading != xi.heading) {
			res |= EIFields.HDR;
		}
		if(ei.rthland != xi.rthland) {
			res |= EIFields.RTL;
		}
		if(ei.action != xi.action) {
			res |= EIFields.ACT;
		}
		if(ei.flag != xi.flag) {
			res |= EIFields.FLAG;
		}
		if(ei.optional != xi.optional) {
			res |= EIFields.OPT;
		}
		return res;
	}

	public void editwp(int no) {
		string posit;
		var ei = create(no, out posit);
		var orig = ei;
		var xorig = ei;
		var dlg = new WPPopEdit(posit);
		dlg.marker_changed.connect((s) => {
				//var typ = Msp.get_wpname(s);
				//MWPLog.message(":DLG: Marker changed type %s\n", typ.to_string());
			});

		dlg.completed.connect((s) => {
				int chg = 0;
				bool ll = false;
				if(s) {
					dlg.extract_data(Msp.Action.UNKNOWN, ref ei);
					if(ei.action == Msp.Action.LAND) {
						var l = dlg.extract_land();
						FWApproach.set(MissionManager.mdx+8, l);
						ll = true;
					}
					chg = eicmp(ei, orig); //Memory.cmp(&ei, &orig, sizeof(EditItem));
					if(chg != 0) {
						var res = extract(ei.no, ei, orig);
						if (!res) {
							dlg.set_jump_dst(orig.jump1);
							var msg = "Invalid jump target (#%d).".printf(ei.jump1);
							var buri = new Gtk.LinkButton.with_label("https://github.com/iNavFlight/inav/wiki/MSP-Navigation-Messages#jump", "INAV Wiki jump validation rules");
							Utils.warning_box(msg, 0, dlg, buri);
						}
						orig = ei;
					}
				} else {
					chg = eicmp(ei, xorig); //Memory.cmp(&ei, &xorig, sizeof(EditItem));
					if(chg != 0) {
						MissionManager.is_dirty = true;
					}
					dlg.close();
				}
				if(chg != 0 || ll) {
					MsnTools.clear_display();
					MsnTools.renumber_mission(MissionManager.current());
					MissionManager.visualise_mission();
				}
			});
		dlg.wpedit(ei);
	}

	private int find_next(int idx, Msp.Action act) {
		var ms = MissionManager.current();
		for(var j = idx+1; j < ms.npoints; j++){
			if(ms.points[j].is_geo()) {
				return -1;
			}
			if(ms.points[j].action == act) {
				return j;
			}
		}
		return -1;
	}

	private void remove_element(int idx, Msp.Action act) {
		var ms = MissionManager.current();
		var delidx = find_next(idx, act);
		MissionItem [] nmis={};
		for(var i = 0; i < ms.npoints; i++) {
			if (i != delidx) {
				nmis += ms.points[i];
			}
		}
		ms.points = nmis;
		ms.npoints = nmis.length;
		if(delidx != -1) {
			for(var i = 0; i < ms.npoints; i++) {
				if(ms.points[i].action == Msp.Action.JUMP &&ms.points[i].param1 > delidx) {
					ms.points[i].param1 -= 1;
				}
			}
		}
		ms.changed();
	}

	private int insert_element(int idx, Msp.Action act) {
		var ms = MissionManager.current();
		MissionItem [] nmis={};
		var added = -1;
		for(var i = 0; i < ms.npoints; i++) {
			nmis += ms.points[i];
			if (idx == i) {
				var mi = new MissionItem();
				mi.action=act;
				nmis += mi;
				added = i+1;
			}
		}
		ms.points = nmis;
		ms.npoints = nmis.length;
		if(added != -1) {
			for(var i = 0; i < ms.npoints; i++) {
				if(ms.points[i].action == Msp.Action.JUMP &&ms.points[i].param1 > added) {
					ms.points[i].param1 += 1;
				}
			}
		}
		ms.changed();
		return added;
	}
}
