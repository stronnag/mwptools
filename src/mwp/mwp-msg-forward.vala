namespace MessageForward {

	void position() {
		uint8[]msg;
		uint8*rp;
		switch (Mwp.conf.forward) {
		case Mwp.FWDS.LTM:
		case Mwp.FWDS.minLTM:
			msg = new uint8[MSize.LTM_GFRAME];
			rp = SEDE.serialise_i32(msg, (int32)(Mwp.msp.td.gps.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lon*1e7));
			*rp++ = (uint8)Mwp.msp.td.gps.gspeed;
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.alt*1e2));
			*rp = (Mwp.msp.td.gps.fix & 3) | (Mwp.msp.td.gps.nsats << 2);
			Mwp.fwddev.forward_ltm('G', msg, MSize.LTM_GFRAME);
			break;

		case Mwp.FWDS.ALL:
		case Mwp.FWDS.MSP1:
		case Mwp.FWDS.MSP2:
			msg = new uint8[MSize.MSP_RAW_GPS];
			rp = SEDE.serialise_i32(msg, (int32)(Mwp.msp.td.gps.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lon*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.alt));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.gspeed *100));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.cog*10));
			SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.hdop*100));
			bool v2 = (Mwp.conf.forward !=  Mwp.FWDS.MSP1);
			Mwp.fwddev.forward_command( Msp.Cmds.RAW_GPS, msg, MSize.MSP_RAW_GPS, v2);
			break;

		case Mwp.FWDS.minMAV:
		case Mwp.FWDS.MAV1:
		case Mwp.FWDS.MAV2:
			msg = new uint8[sizeof(Mav.MAVLINK_GPS_RAW_INT)];
			var now = new DateTime.now_utc();
			int64 ms = now.to_unix()*1000;
			rp = SEDE.serialise_u32(msg, (uint32)(ms & 0xffffffff));
			rp = SEDE.serialise_u32(rp, (uint32) (ms >> 32));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lon*1e7));
			var alt = 1000*(Mwp.msp.td.gps.alt + Mwp.msp.td.origin.alt);
			rp = SEDE.serialise_i32(rp, (int32)(alt));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.hdop*100));
			rp = SEDE.serialise_u16(rp, (uint16)(0xffff));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.gspeed *100));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.cog*100));
			uint8 fix = (Mwp.msp.td.gps.fix == 0) ? 0 : uint8.max(2, Mwp.msp.td.gps.fix-1);
			*rp++ = fix;
			*rp++ = Mwp.msp.td.gps.nsats;
			var msize = (intptr)rp - (intptr)msg;
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_GPS_RAW_INT), msg, msize, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			break;

		default:
			break;
		}
	}

	void attitude() {
		uint8[]msg;
		uint8*rp;
		switch (Mwp.conf.forward) {
		case Mwp.FWDS.LTM:
		case Mwp.FWDS.minLTM:
			msg = new uint8[MSize.LTM_AFRAME];
			rp = SEDE.serialise_i16(msg, (int16)(-Mwp.msp.td.atti.angx));
			rp = SEDE.serialise_i16(rp, (int16)(-Mwp.msp.td.atti.angy));
			SEDE.serialise_i16(rp, (int16)Mwp.msp.td.atti.yaw);
			Mwp.fwddev.forward_ltm('A', msg, MSize.LTM_AFRAME);
			break;

		case Mwp.FWDS.ALL:
		case Mwp.FWDS.MSP1:
		case Mwp.FWDS.MSP2:
			msg = new uint8[MSize.MSP_ATTITUDE];
			int16 atx = (int16)( -Mwp.msp.td.atti.angx);
			if (atx > 180) {
				atx -= 360;
			}
			int16 h = (int16) Mwp.msp.td.atti.yaw;
			if (h > 180) {
				h -= 360;
			}
			rp = SEDE.serialise_i16(msg, atx);
			rp = SEDE.serialise_i16(rp, (int16)(-Mwp.msp.td.atti.angy));
			SEDE.serialise_i16(rp, h);
			bool v2 = (Mwp.conf.forward !=  Mwp.FWDS.MSP1);
			Mwp.fwddev.forward_command( Msp.Cmds.ATTITUDE, msg, MSize.MSP_ATTITUDE, v2);
			break;

		case Mwp.FWDS.minMAV:
		case Mwp.FWDS.MAV1:
		case Mwp.FWDS.MAV2:
			msg = new uint8[sizeof(Mav.MAVLINK_ATTITUDE)];
			rp = SEDE.serialise_u32(msg, 0);
			float fval;
			fval = (float) (-Mwp.msp.td.atti.angx / Mwp.RAD2DEG);
			// avoid 'dereferencing type-punned pointer' warnings
			void *p = (void*)&fval;
			rp = SEDE.serialise_u32(msg, *((uint32*)p));
			fval = (float) (Mwp.msp.td.atti.angy / Mwp.RAD2DEG);
			rp = SEDE.serialise_u32(msg, *((uint32*)p));
			fval = (float) Mwp.msp.td.atti.yaw;
			if (fval > 180.0f) {
				fval -= 360.0f;
			}
			fval /= (float)Mwp.RAD2DEG;

			rp = SEDE.serialise_u32(msg, *((uint32*)p));
			rp = SEDE.serialise_u32(msg, 0);
			rp = SEDE.serialise_u32(msg, 0);
			rp = SEDE.serialise_u32(msg, 0);
			var msize = (intptr)rp - (intptr)msg;
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_ATTITUDE), msg, msize, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			break;

		default:
			break;
		}
	}

	void status() {
		uint8[]msg;
		uint8*rp;
		switch (Mwp.conf.forward) {
		case Mwp.FWDS.LTM:
		case Mwp.FWDS.minLTM:
			msg = new uint8[MSize.LTM_SFRAME];
			rp = SEDE.serialise_u16(msg, (uint16)(Mwp.msp.td.power.volts*1000));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.power.mah));
			*rp++ =  Mwp.msp.td.rssi.rssi*255/1023;
			*rp++ = 0;
			*rp = (Mwp.msp.td.state.state &3) | (Mwp.msp.td.state.ltmstate << 2);
			Mwp.fwddev.forward_ltm('S', msg, MSize.LTM_SFRAME);
			break;

		case Mwp.FWDS.MSP1:
			msg = new uint8[MSize.MSP_STATUS];
			rp = SEDE.serialise_u16(msg, 0);
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_u16(rp, Mwp.xsensor);
			rp = SEDE.serialise_u32(msg, (uint32)(Mwp.msp.td.state.state &1));
			Mwp.fwddev.forward_command( Msp.Cmds.STATUS, msg, MSize.MSP_STATUS);
			msg = new uint8[MSize.MSP_ANALOG];
			rp = msg;
			*rp++ = (uint8)(Mwp.msp.td.power.volts*10);
			rp = SEDE.serialise_u16(msg, (uint16)(Mwp.msp.td.power.mah));
			rp = SEDE.serialise_u16(rp, (uint16)Mwp.msp.td.rssi.rssi);
			rp = SEDE.serialise_u16(rp, 0);
			Mwp.fwddev.forward_command( Msp.Cmds.ANALOG, msg, MSize.MSP_ANALOG);
			break;
		case Mwp.FWDS.ALL:
		case Mwp.FWDS.MSP2:
			msg = new uint8[MSize.MSP2_INAV_STATUS];
			rp = SEDE.serialise_u16(msg, 0);
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_u16(rp, Mwp.xsensor);  // sensor status ...
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_u32(rp, Mwp.xarm_flags); // arming flags
			uint64 f0 = (uint64)(Mwp.msp.td.state.state &1);
			switch (Mwp.msp.td.state.ltmstate) {
			case Msp.Ltm.HORIZON:
				f0 |= Mwp.horz_mask;
				break;
			case Msp.Ltm.ANGLE:
				f0 |= Mwp.angle_mask;
				break;
			case Msp.Ltm.RTH:
				f0 |= Mwp.rth_mask;
				break;
			case Msp.Ltm.POSHOLD:
				f0 |= Mwp.ph_mask;
				break;
			case Msp.Ltm.WAYPOINTS:
				f0 |= Mwp.wp_mask;
				break;
			case Msp.Ltm.CRUISE:
				f0 |= Mwp.cr_mask;
				break;
			default:
				break;
			}
			if(Mwp.xfailsafe) {
				f0 |= Mwp.fs_mask;
			}
			rp = SEDE.serialise_u32(rp, (uint32)(f0 & 0xffffffff));
			rp = SEDE.serialise_u32(rp, (uint32) (f0 >> 32));
			*rp = 0;
			Mwp.fwddev.forward_command(Msp.Cmds.INAV_STATUS, msg, MSize.MSP2_INAV_STATUS, true);
			msg = new uint8[MSize.MSP_ANALOG2]{0};
			rp = msg;
			rp = SEDE.serialise_u16(msg+1, (uint16)Mwp.msp.td.power.volts*100);
			rp = SEDE.serialise_u16(msg+9, (uint16)Mwp.msp.td.power.mah);
			rp = SEDE.serialise_u16(msg+22, (uint16)Mwp.msp.td.rssi.rssi);
			Mwp.fwddev.forward_command( Msp.Cmds.ANALOG2, msg, MSize.MSP_ANALOG2, true);
			break;

		case Mwp.FWDS.minMAV:
		case Mwp.FWDS.MAV1:
		case Mwp.FWDS.MAV2:
			msg = new uint8[sizeof(Mav.MAVLINK_SYS_STATUS)]{0};
			uint32 flag = 0; // fixme
			rp = SEDE.serialise_u32(msg, flag); // sensors, fixme, maybe
			rp = SEDE.serialise_u32(rp, 0);
			rp = SEDE.serialise_u32(rp, 0);
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_u16(rp, (uint16)Mwp.msp.td.power.volts*1000);
			rp = SEDE.serialise_u16(rp, (uint16)0xffff);
			rp = SEDE.serialise_u32(rp, 0);
			rp = SEDE.serialise_u32(rp, 0);
			rp = SEDE.serialise_u32(rp, 0);
			*rp++ = 0;
			var msize = (intptr)rp - (intptr)msg;
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_ID_SYS_STATUS), msg, msize, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			msg = new uint8[sizeof(Mav.MAVLINK_RC_CHANNELS)]{0};
			msg[21] =  (uint8)(Mwp.msp.td.rssi.rssi*100/1023);
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_RC_CHANNELS), msg, 22, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			break;

		default:
			break;
		}
	}

	void origin() {
		uint8[]msg;
		uint8*rp;
		switch (Mwp.conf.forward) {
		case Mwp.FWDS.LTM:
		case Mwp.FWDS.minLTM:
			msg = new uint8[MSize.LTM_OFRAME];
			rp = SEDE.serialise_i32(msg, (int32)(Mwp.msp.td.origin.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.origin.lon*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.origin.alt*1e2));
			*rp++ = 1;
			*rp = (uint8)(Mwp.msp.td.gps.fix > 0);
			Mwp.fwddev.forward_ltm('O', msg, MSize.LTM_OFRAME);
			break;

		case Mwp.FWDS.ALL:
		case Mwp.FWDS.MSP1:
		case Mwp.FWDS.MSP2:
			msg = new uint8[MSize.MSP_WP];
			rp = msg;
			*rp++ = 0;
			*rp++ = Msp.Action.WAYPOINT;
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.origin.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.origin.lon*1e7));
			rp = SEDE.serialise_i32(rp, 0);
			rp = SEDE.serialise_i16(rp, 0);
			rp = SEDE.serialise_i16(rp, 0);
			rp = SEDE.serialise_i16(rp, 0);
			*rp = 0xa5;
			bool v2 = (Mwp.conf.forward !=  Mwp.FWDS.MSP1);
			Mwp.fwddev.forward_command( Msp.Cmds.WP, msg, MSize.MSP_WP, v2);
			break;

		case Mwp.FWDS.minMAV:
		case Mwp.FWDS.MAV1:
		case Mwp.FWDS.MAV2:
			msg = new uint8[sizeof(Mav.MAVLINK_GPS_GLOBAL_ORIGIN)];
			rp = SEDE.serialise_i32(msg, (int32)(Mwp.msp.td.origin.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.origin.lon*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.origin.alt*1e3));
			var msize = (intptr)rp - (intptr)msg;
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_GPS_GLOBAL_ORIGIN), msg, msize, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			break;

		default:
			break;
		}
	}

	private uint16 cmd_to_ucmd(uint c) {
		if (c > Msp.MAV_BASE) {
			return (uint16)(c - Msp.MAV_BASE);
		}
		if (c > Msp.LTM_BASE) {
			return (uint16)(c - Msp.LTM_BASE);
		}
		return (uint16)c;
	}
}
