public class LogReader : Object {
	public enum Ftype {
        RAW=0,
		V2=2,
		JS=4,
    }

	private FileStream fp;
    public Ftype mode {private set; get;}
	public double elapsed;
	public size_t nbytes {private set; get;}

	public LogReader() {
		elapsed = 0.0;
		nbytes = 0;
	}

	public bool open(string s) {
		fp = FileStream.open(s, "r");
		mode = Ftype.RAW;
		if (fp != null) {
			uint8[] buf = new uint8[3];
			if(fp.read(buf) == 3) {
				if(buf[0] == 'v' && buf[1] == '2' && buf[2] == '\n') {
					mode = Ftype.V2;
					stderr.printf("V2 data\n");
				} else if (buf[0] == '{' && buf[1] == '"') { // "
					mode = Ftype.JS;
					fp.rewind();
				} else {
					fp.rewind();
				}
			}
			stderr.printf("Opened\n");
			return true;
		}
		return false;
	}

	public size_t read_buffer(ref uint8[] b) {
		size_t nr = -1;
		if (mode == Ftype.RAW) {
			b = new uint8[128];
			nr = fp.read(b);
			if (nr == 0)
				nr = -1;
		} else if (mode == Ftype.V2) {
			V2HEADER hdr={0};
			nr = fp.read((uint8[])&hdr);
			if (nr > 0) {
				b = new uint8[(size_t)hdr.size];
				nr = fp.read(b);
				if (nr > 0) {
					if (hdr.direction == 'i') {
						elapsed = hdr.offset;
						nbytes +=  (size_t)hdr.size;
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
			var jsbuf = fp.read_line();
			if (jsbuf != null) {
				try {
					var parser = new Json.Parser ();
					if (parser.load_from_data (jsbuf)) {
						var obj = parser.get_root ().get_object ();
						uint8 dirn = 0;
						if (obj.has_member("direction")) {
							dirn = (uint8)obj.get_int_member("direction");
							if (dirn == 'i') {
								if (obj.has_member("stamp")) {
									elapsed = obj.get_double_member("stamp");
								}
								if (obj.has_member("length")) {
									nr = (int) obj.get_int_member("length");
									nbytes += nr;
								}
								if (obj.has_member("rawdata")) {
									var s = obj.get_string_member("rawdata");
									b = Base64.decode(s);
								}
							} else {
								return 0;
							}
						}
					}
				} catch {};
			} else {
				return -1;
			}
		}
		return nr;
	}
}

#if TEST
public static int main(string?[]args) {
	var lr = new LogReader();
	if (lr.open(args[1])) {
		stderr.printf("Ready to read %s\n", lr.mode.to_string());
		uint8[] buf={};
		size_t nr;
		while((nr = lr.read_buffer(ref buf)) != -1) ; /* read all */
		stdout.printf("%d bytes in %.1f\n", (int)lr.nbytes,lr.elapsed);
	}
   	return 0;
}
#endif
