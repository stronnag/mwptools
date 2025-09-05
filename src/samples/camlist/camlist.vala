
int main(string[]?args) {
	if(args.length > 1) {
		Variant x = null;
		try {
			uint8 []data;
			GLib.Variant? val = null;
			string? key = null;
			FileUtils.get_data(args[1], out data);
			var b = new Bytes(data);
			x = new Variant.from_bytes(VariantType.VARDICT, b, true);
			VariantIter iter = x.iterator ();
			while (iter.next ("{sv}", out key, out val)) {
				print ("Camera '%s' index %d\n", key, val.get_int16());
			}
		} catch (Error e) {
			print("Error %s\n", e.message);
		}
	}
	return 0;
}