namespace MessageForward {
	uint8 msg[512];
	void position() {
		uint8*rp;
		switch (Mwp.conf.forward) {
		case Mwp.FWDS.LTM:
			msg = {0};
			rp = SEDE.serialise_i32(msg, (int32)(Mwp.msp.td.gps.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lon*1e7));
			*rp++ = (uint8)Mwp.msp.td.gps.gspeed;
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.alt.alt*1e2));
			*rp = (Mwp.msp.td.gps.fix & 3) | (Mwp.msp.td.gps.nsats << 2);
			Mwp.fwddev.forward_ltm('G', msg, MSize.LTM_GFRAME);
			break;

		case Mwp.FWDS.MSP1:
		case Mwp.FWDS.MSP2:
			msg = {0};
			uint8 fix = Mwp.msp.td.gps.fix;
			rp = msg;
			*rp ++ = fix;
			*rp++ = Mwp.msp.td.gps.nsats;
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lon*1e7));
			var alt = (int16)Mwp.msp.td.gps.alt;
			rp = SEDE.serialise_i16(rp, alt);
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.gspeed *100));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.cog*10));
			SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.hdop*100));
			bool v2 = (Mwp.conf.forward !=  Mwp.FWDS.MSP1);
			Mwp.fwddev.forward_command( Msp.Cmds.RAW_GPS, msg, MSize.MSP_RAW_GPS, v2);
			msg = {0};
			rp = SEDE.serialise_i32(msg, (int32)(Mwp.msp.td.alt.alt * 100));
			rp = SEDE.serialise_i16(rp, (int16)(Mwp.msp.td.alt.vario * 100));
			Mwp.fwddev.forward_command( Msp.Cmds.ALTITUDE, msg, MSize.MSP_ALTITUDE, v2);
			break;

		case Mwp.FWDS.MAV1:
		case Mwp.FWDS.MAV2:
			msg = {0};
			var now = new DateTime.now_utc();
			int64 ms = now.to_unix()*1000;
			rp = SEDE.serialise_u32(msg, (uint32)(ms & 0xffffffff));
			rp = SEDE.serialise_u32(rp, (uint32) (ms >> 32));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lon*1e7));
			// (mm)	Altitude (MSL). Positive for up.
			int32 alt = (int32)(1000*Mwp.msp.td.gps.alt);
			rp = SEDE.serialise_i32(rp, (int32)(alt));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.hdop*100));
			rp = SEDE.serialise_u16(rp, (uint16)(0xffff));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.gspeed *100));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.gps.cog*100));
			*rp++ = Mwp.msp.td.gps.fix;
			*rp++ = Mwp.msp.td.gps.nsats;
			var msize = (intptr)rp - (intptr)msg;
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_GPS_RAW_INT), msg, msize, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			msg = {0};
			rp = SEDE.serialise_u32(msg, (uint32)(Mwp.duration*1000)); // fixme;
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.gps.lon*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(alt)); // GPS
			alt = (int32)(1000*Mwp.msp.td.alt.alt);
			rp = SEDE.serialise_i32(rp, (int32)(alt)); // Baro
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_i16(rp, (int16)(100*Mwp.msp.td.atti.yaw));
			msize = (intptr)rp - (intptr)msg;
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_GPS_GLOBAL_INT), msg, msize, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			break;

		default:
			break;
		}
	}

	void attitude() {
		uint8*rp;
		switch (Mwp.conf.forward) {
		case Mwp.FWDS.LTM:
			msg = {0};
			int16 roll = (int16)Mwp.msp.td.atti.angx;
			if(roll > 180) {
				roll -=360;
			}
			rp = SEDE.serialise_i16(msg, (int16)(-Mwp.msp.td.atti.angy));
			rp = SEDE.serialise_i16(rp,-roll);
			SEDE.serialise_i16(rp, (int16)Mwp.msp.td.atti.yaw);
			Mwp.fwddev.forward_ltm('A', msg, MSize.LTM_AFRAME);
			break;

		case Mwp.FWDS.MSP1:
		case Mwp.FWDS.MSP2:
			msg = {0};
			int16 atx = (int16)( -Mwp.msp.td.atti.angx);
			if (atx > 180) {
				atx -= 360;
			}
			int16 h = (int16) Mwp.msp.td.atti.yaw;
			if (h > 180) {
				h -= 360;
			}
			rp = SEDE.serialise_i16(msg, 10*atx);
			rp = SEDE.serialise_i16(rp, (int16)(-10*Mwp.msp.td.atti.angy));
			SEDE.serialise_i16(rp, h);
			bool v2 = (Mwp.conf.forward !=  Mwp.FWDS.MSP1);
			Mwp.fwddev.forward_command( Msp.Cmds.ATTITUDE, msg, MSize.MSP_ATTITUDE, v2);
			break;

		case Mwp.FWDS.MAV1:
		case Mwp.FWDS.MAV2:
			msg = {0};
			Mav.MAVLINK_ATTITUDE m = {0};
			float f;
			f = Mwp.mhead;
			if (f > 180) {
				f -= 180.0f;
			}
			m.yaw = f/(float)Mwp.RAD2DEG;
			f = (float)(-Mwp.msp.td.atti.angx) / (float)Mwp.RAD2DEG;
			m.roll = f;
			m.pitch = (float)Mwp.msp.td.atti.angy / (float)Mwp.RAD2DEG;
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_ATTITUDE), (uint8[])&m, 28, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			break;

		default:
			break;
		}
	}

	void status() {
		uint8*rp;
		switch (Mwp.conf.forward) {
		case Mwp.FWDS.LTM:
			msg = {0};
			rp = SEDE.serialise_u16(msg, (uint16)(Mwp.msp.td.power.volts*1000));
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.power.mah));
			*rp++ =  Mwp.msp.td.rssi.rssi*255/1023;
			*rp++ = 0;
			*rp = (Mwp.msp.td.state.state &3) | (Mwp.msp.td.state.ltmstate << 2);
			Mwp.fwddev.forward_ltm('S', msg, MSize.LTM_SFRAME);
			break;

		case Mwp.FWDS.MSP1:
			msg = {0};
			rp = SEDE.serialise_u16(msg, 0);
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_u16(rp, Mwp.xsensor);
			rp = SEDE.serialise_u32(rp, (uint32)(Mwp.msp.td.state.state &1));
			Mwp.fwddev.forward_command( Msp.Cmds.STATUS, msg, MSize.MSP_STATUS);
			msg = {0};
			rp = msg;
			*rp++ = (uint8)((Mwp.msp.td.power.volts+0.05)*10);
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.power.mah));
			rp = SEDE.serialise_u16(rp, (uint16)Mwp.msp.td.rssi.rssi);
			rp = SEDE.serialise_u16(rp, 0);
			Mwp.fwddev.forward_command( Msp.Cmds.ANALOG, msg, MSize.MSP_ANALOG);
			break;
		case Mwp.FWDS.MSP2:
			msg = {0};
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
			if(Mwp.armed != 0) {
				f0 |= Mwp.arm_mask;
			}
			rp = SEDE.serialise_u32(rp, (uint32)(f0 & 0xffffffff));
			rp = SEDE.serialise_u32(rp, (uint32) (f0 >> 32));
			*rp = 0;
			Mwp.fwddev.forward_command(Msp.Cmds.INAV_STATUS, msg, MSize.MSP2_INAV_STATUS, true);
			msg = {0};
			SEDE.serialise_u16(&msg[1], (uint16)Mwp.msp.td.power.volts*100);
			SEDE.serialise_u16(&msg[9], (uint16)Mwp.msp.td.power.mah);
			SEDE.serialise_u16(&msg[22], (uint16)Mwp.msp.td.rssi.rssi);
			Mwp.fwddev.forward_command( Msp.Cmds.ANALOG2, msg, MSize.MSP_ANALOG2, true);
			break;

		case Mwp.FWDS.MAV1:
		case Mwp.FWDS.MAV2:
			msg = {0};
			uint32 flag = 0; // fixme
			rp = SEDE.serialise_u32(msg, flag); // sensors, fixme, maybe
			rp = SEDE.serialise_u32(rp, 0);
			rp = SEDE.serialise_u32(rp, 0);
			rp = SEDE.serialise_u16(rp, 0);
			rp = SEDE.serialise_u16(rp, (uint16)(Mwp.msp.td.power.volts*1000));
			rp = SEDE.serialise_u16(rp, (uint16)0xffff);
			rp = SEDE.serialise_u32(rp, 0);
			rp = SEDE.serialise_u32(rp, 0);
			rp = SEDE.serialise_u32(rp, 0);
			*rp++ = 0;
			var msize = (intptr)rp - (intptr)msg;
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_ID_SYS_STATUS), msg, msize, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			msg = {0};
			msg[21] =  (uint8)(Mwp.msp.td.rssi.rssi*100/1023);
			Mwp.fwddev.forward_mav(cmd_to_ucmd(Msp.Cmds.MAVLINK_MSG_RC_CHANNELS), msg, 22, (Mwp.conf.forward == Mwp.FWDS.MAV1) ? 1 : 2);
			break;

		default:
			break;
		}
	}

	void origin() {
		uint8*rp;
		switch (Mwp.conf.forward) {
		case Mwp.FWDS.LTM:
			msg = {0};
			rp = SEDE.serialise_i32(msg, (int32)(Mwp.msp.td.origin.lat*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.origin.lon*1e7));
			rp = SEDE.serialise_i32(rp, (int32)(Mwp.msp.td.origin.alt*1e2));
			*rp++ = 1;
			*rp = Mwp.msp.td.gps.fix;
			Mwp.fwddev.forward_ltm('O', msg, MSize.LTM_OFRAME);
			break;

		case Mwp.FWDS.MSP1:
		case Mwp.FWDS.MSP2:
			msg = {0};
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

		case Mwp.FWDS.MAV1:
		case Mwp.FWDS.MAV2:
			msg = {0};
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
