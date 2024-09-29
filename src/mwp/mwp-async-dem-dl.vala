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
		} catch (Error e) {
			MWPLog.message("gunzip fails %s %s\n", gzname, e.message);
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
					mutex.unlock();
					while (true) {
						uint n;
						mutex.lock();
						n = list.length();
						mutex.unlock();
						if ( n == 0) {
							break;
						}
						mutex.lock();
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
							} else {
								var tmp = Environment.get_tmp_dir();
								var fn = s + ".gz";
								var uri = "https://s3.amazonaws.com/elevation-tiles-prod/skadi/" + fn[0:3]+"/"+ fn;
								fn = tmp + "/" + fn;
								File file = File.new_for_path(fn);
								MWPLog.message("start DEM D/L %s => %s\n", uri, fn);
								FileUtils.unlink(fn);
								try {
									FileOutputStream os = file.create (FileCreateFlags.REPLACE_DESTINATION);
									var session = new Soup.Session();

									var message = new Soup.Message ("GET", uri);
#if MODERN_SOUP
									session.send_and_splice(message, os,  OutputStreamSpliceFlags.CLOSE_TARGET);
#else
									var stream = session.send(message, null);
									os.splice (stream, OutputStreamSpliceFlags.CLOSE_TARGET);
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
					}
				}
			});
		yield;
		return thr.join();
	}

	public void add_queue(string s) {
		var found = false;
		mutex.lock();
		for( unowned SList<string> lp = list; lp != null; ) {
			var sl = lp.data;
			if (sl == s) {
				found = true;
			}
			lp = lp.next;
        }
		if (!found) {
			pop = true;
			list.append(s);
			cond.signal();
		}
		mutex.unlock();
	}
}
