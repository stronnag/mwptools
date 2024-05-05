int main (string?[] args) {
	string fpath = args[1];
	Posix.Stat st;
	if(Posix.stat(fpath, out st) == 0) {
		uint8[] buf = new uint8[st.st_size];
		if (buf != null) {
			FileStream fs= FileStream.open (fpath, "r");
			fs.read(buf, st.st_size);
			ReadSB.Pbuf[] acs;
			var na = ReadSB.decode_ac_pb(buf, out acs);
			print("seen %d valid / asc.length %d\n", na, acs.length);
			foreach(var a in acs) {
				uint8 et = (a.catx&0xf) | (a.catx>>4)/0xa;
				var dt = new DateTime.from_unix_local ((int64)(a.seen_tm/1000));
				var msec = (int)a.seen_tm%1000;
				print("AM %X [%s] (%X %d) %f %f alt:%d gspd:%u hdg:%u seen: %s.%03d pos_seen: %u\n",
					  a.addr, (string)a.name, a.catx, et, a.lat, a.lon,
					  a.alt, a.speed, a.hdg, dt.format("%T"), msec, a.seen_pos);
			}
		}
	}
	return 0;
}