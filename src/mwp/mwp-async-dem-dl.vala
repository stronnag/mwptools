public class AsyncDL : Object  {
	private SList <string> list;
	private Mutex mutex;
	private Cond cond;
	private string _demdir;
	private bool pop = false;

    public signal void loaded(string s);

    public AsyncDL(string demdir) {
		_demdir = demdir;
		list = new SList<string>();
		cond = Cond();
		mutex = Mutex();
    }

	private void decompress(string gzname, string fname) {
		var conv = new ZlibDecompressor (ZlibCompressorFormat.GZIP);
		var srcf = File.new_for_path(gzname);
		try {
			var src= srcf.read ();
			var dstf = File.new_for_path(_demdir+"/"+fname);
			var dst = dstf.replace (null, false, 0);
			var conv_stream = new ConverterOutputStream (dst, conv);
			conv_stream.splice (src, 0);
			//			MWPLog.message("gunzipped %s %s\n", gzname, dstf.get_path());
		} catch (Error e) {
			//			MWPLog.message("gunzip fails %s\n", e.message);
		}
		FileUtils.unlink(gzname);
	}

	public async bool run_async () {

		var thr = new Thread<bool>("hqueue", () => {
				while (true) {
                    mutex.lock ();
					while (!pop) {
						cond.wait(mutex);
					}
					pop = false;
					var s = list.nth_data(0);
					mutex.unlock();

					if (s == "!") {
                        Idle.add (run_async.callback);
						return false;
					} else {
						var xfn = Path.build_filename(_demdir, s);
						var fd = Posix.open(xfn, Posix.O_RDONLY);
						if (fd != -1) {
							MWPLog.message("Skipping %s\n", xfn);
							Posix.close(fd);
							continue;
						}
						var tmp = Environment.get_tmp_dir();
						var fn = s + ".gz";
						var uri = "https://s3.amazonaws.com/elevation-tiles-prod/skadi/" + fn[0:3]+"/"+ fn;
						fn = tmp + "/" + fn;
						File file = File.new_for_path(fn);
						MWPLog.message("start DEM D/L %s => %s\n", uri, fn);
						try {
							FileOutputStream os = file.create (FileCreateFlags.REPLACE_DESTINATION);
							var session = new Soup.Session();

#if COLDSOUP
							Soup.Request request = session.request (uri);
							InputStream stream = request.send ();
							os.splice (stream, OutputStreamSpliceFlags.CLOSE_TARGET);
#else
							var message = new Soup.Message ("GET", uri);
							session.send_and_splice(message, os,  OutputStreamSpliceFlags.CLOSE_TARGET);
#endif
							MWPLog.message("Finished DEM D/L %s\n", fn);
							decompress(fn, s);
                            loaded(s);
						} catch (Error e){
							MWPLog.message("failed D/L %s\n", e.message);
						}
					}
                    mutex.lock();
					list.remove_link(list);
					mutex.unlock();
				}
			});
		yield;
		return thr.join();
	}

	public void add_queue(string s) {
		var found = false;
		for( unowned SList<string> lp = list; lp != null; ) {
			var sl = lp.data;
			if (sl == s) {
				found = true;
			}
			lp = lp.next;
        }
		if (!found) {
			mutex.lock();
			pop = true;
			list.append(s);
			cond.signal();
			mutex.unlock();
		}
	}

}
