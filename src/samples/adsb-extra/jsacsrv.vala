
const string AFILE="/run/dump1090/aircraft.json";

public static int main (string[] args) {
	SList<Socket> slist = new SList<Socket>();
	int port = 37007;
	string fpath = AFILE;

	var options = new OptionEntry[] {
		{"port", 'p', 0, OptionArg.INT, out port, "TCP Port", null},
		{"acfile", 'f', 0, OptionArg.STRING, out fpath, "File path", null},
		{null}
		};

	try {
		var opt = new OptionContext(" - dump1090 JSON server");
		opt.set_help_enabled(true);
		opt.add_main_entries(options, null);
		opt.parse(ref args);
	} catch (OptionError e) {
        stderr.printf("Error: %s\n", e.message);
        stderr.printf("Run '%s --help' to see a full list of available "+
                      "options\n", args[0]);
        return 1;
    }

	try {
		SocketService service = new SocketService ();
		File file = File.new_for_path (fpath);
		FileMonitor monitor = file.monitor (FileMonitorFlags.NONE, null);
		print ("Monitoring: %s for [::]:%d\n", file.get_path(), port);

		monitor.changed.connect ((src, dest, event) => {
				if(event == FileMonitorEvent.CHANGES_DONE_HINT) {
					if(slist.length() != 0) {
						string json;
						try {
							FileUtils.get_contents(fpath, out json);
							slist.@foreach((skt) => {
									try {
										skt.send(json.data);
									} catch (Error e) {
										stderr.printf("send %s\n", e.message);
									}
								});
						} catch (Error e){
							stderr.printf("Read %s\n", e.message);
						}
					}
				}
		});

		service.add_inet_port ((uint16)port, null);
		service.incoming.connect ((conn, s) => {
				var skt = conn.get_socket();
				var fd = skt.get_fd();
				slist.append(skt);
				var io_read = new IOChannel.unix_new(fd);
				io_read.add_watch(IOCondition.IN|IOCondition.HUP|
											IOCondition.NVAL|IOCondition.ERR, (io,cond) => {
									  var fd_ = io.unix_get_fd();
									  try {
										  unowned var sl = slist.search(fd_, (s,f) => {
												  return (s.get_fd() - (int)((int64)f));
											  });
										  io.shutdown(true);
										  slist.remove(sl.data);
									  } catch  {}
									  return false;
								  });
				return false;
		});
		service.start ();
		MainLoop loop = new MainLoop ();
		loop.run ();
	} catch (Error e) {
		stderr.printf ("Error: %s\n", e.message);
	}
	return 0;
}
