
int main(string[]?args) {
	string fn;
	if(args.length < 2) {
		var uc = Environment.get_user_config_dir();
		fn = GLib.Path.build_filename(uc, "mwp", ".cameras.v0.dict");

	} else {
		fn = args[1];
	}
	Variant x = null;
	try {
		uint8 []data;
		GLib.Variant? val = null;
		string? key = null;
		FileUtils.get_data(fn, out data);
		var b = new Bytes(data);
		x = new Variant.from_bytes(VariantType.VARDICT, b, true);
		VariantIter iter = x.iterator ();
		while (iter.next ("{sv}", out key, out val)) {
			print ("Camera '%s' index %d\n", key, val.get_int16());
		}
	} catch (Error e) {
		print("Error %s\n", e.message);
	}
	return 0;
}