public class LogReader : Object {
	private struct Header {
		double delta;
		uint16 size;
		uint8 dirn;
	}
	public enum Ftype {
        RAW=0,
		V2=2,
		JS=4,
    }

	private int fd;
    public Ftype mode {private set; get;}
	public double elapsed;
	public size_t nbytes {private set; get;}

	public LogReader() {
		elapsed = 0.0;
		nbytes = 0;
	}

	public bool open(string s) {
		fd = Posix.open(s, Posix.O_RDONLY);
		mode = Ftype.RAW;
		if (fd != -1) {
			uint8[] buf = new uint8[3];
			if(Posix.read(fd, buf, 3) == 3) {
				if(buf[0] == 'v' && buf[1] == '2' && buf[2] == '\n') {
					mode = Ftype.V2;
					stderr.printf("V2 data\n");
				} else if (buf[0] == '{' && buf[1] == '"') { // "
					mode = Ftype.JS;
					Posix.lseek(fd, 0, Posix.SEEK_SET);
				} else {
					Posix.lseek(fd, 0, Posix.SEEK_SET);
				}
			}
			stderr.printf("Opened\n");
			return true;
		}
		return false;
	}

	public size_t read_buffer(uint8[] b) {
		size_t nr = -1;
		if (mode == Ftype.RAW) {
			nr = Posix.read(fd, b, 128);
		} else if (mode == Ftype.V2) {
			Header hdr={0};
			uint8[] hb=new uint8[11];
			nr = Posix.read(fd, hb, 11);
			if (nr > 0) {
				hdr.delta = *((double*)&hb[0]);
				hdr.size = *((uint16*)&hb[8]);
				hdr.dirn = hb[10];
				nr = Posix.read(fd, b, (size_t)hdr.size);
				if (nr > 0) {
					if (hdr.dirn == 'i') {
						elapsed = hdr.delta;
						nbytes += nr;
					} else {
						nr = 0;
					}
				} else {
					return -1;
				}
			} else {
				return -1;
			}
		} else if (mode == Ftype.JS) {
			uint8[] jsbuf = new uint8[1024];
			var nj = 0;
			for (;;) {
				uint8 c = 0;
				var n = Posix.read(fd, &c, 1);
				if (n != 1)
					return -1;
				if (c == 10) {
					break;
				} else {
					jsbuf[nj] = c;
					nj++;
				}
			}
			if(nj > 0) {
				try {
					var parser = new Json.Parser ();
					jsbuf[nj] = 0;
					if (parser.load_from_data ((string)jsbuf)) {
						var obj = parser.get_root ().get_object ();
						uint8 dirn = 0;
						int ns = 0;
						if (obj.has_member("direction")) {
							dirn = (uint8)obj.get_int_member("direction");
							if (dirn == 'i') {
								if (obj.has_member("stamp")) {
									elapsed = obj.get_double_member("stamp");
								}
								if (obj.has_member("length")) {
									ns = (int) obj.get_int_member("length");
									nbytes += ns;
								}
								if (obj.has_member("rawdata")) {
									var s = obj.get_string_member("rawdata");
									var bs = Base64.decode(s);
									if(ns == bs.length) {
										for(var j = 0; j < ns; j++) {
											b[j] = bs[j];
										}
										return ns;
									}
								}
							} else {
								return 0;
							}
						}
					}
				} catch {};
			}
			return -1;
		}
		return nr;
	}
}

#if TEST
public static int main(string?[]args) {
	var lr = new LogReader();
	if (lr.open(args[1])) {
		stderr.printf("Ready to read %s\n", lr.mode.to_string());
		var buf = new uint8[1024];
		size_t nr;
		while((nr = lr.read_buffer(buf)) != -1) {
		}
		stdout.printf("%d bytes in %.1f\n", (int)lr.nbytes,lr.elapsed);
	}
   	return 0;
}
#endif
