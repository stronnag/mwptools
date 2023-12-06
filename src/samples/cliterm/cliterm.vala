private static int baud = 115200;
private static string eolmstr;
private static string dev;
private static bool noinit=false;
private static bool msc=false;
private static bool gpspass=false;
private static string rcfile=null;
private static int eolm;
private static int cli_delay=0;
private static MainLoop ml;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", "115200"},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
    { "noinit", 'n', 0,  OptionArg.NONE, out noinit, "noinit", "false"},
    { "cli-delay", 'W', 0,  OptionArg.INT, out cli_delay, "delay", "0"},
    { "msc", 'm', 0,  OptionArg.NONE, out msc, "msc mode", "false"},
    { "gpspass", 'g', 0,  OptionArg.NONE, out gpspass, "gpspassthrough", "false"},
    { "gpspass", 'p', 0,  OptionArg.NONE, out gpspass, "gpspassthrough", "false"},
    { "file", 'f', 0, OptionArg.STRING, out rcfile, "file", null},
    { "eolmode", 'm', 0, OptionArg.STRING, out eolmstr, "eol mode", "[cr,lf,crlf,crcrlf]"},
    {null}
};

class CliTerm : Object {
    private MWSerial msp;
    private MWSerial.ProtoMode oldmode;
    public DevManager dmgr;

    private string eol;
    private bool sendpass = false;
	private uint8 inavvers;
	private Posix.termios oldtio = Posix.termios();

	public CliTerm() {
	}

	public void init() {
        msp= new MWSerial();
		dmgr = new DevManager();
        dmgr.device_added.connect((sdev) => {
				if (dev == null) {
					if(!msp.available && sdev.type == DevMask.USB) {
						open_device(sdev.name);
					}
				}
            });

        dmgr.device_removed.connect((sdev) => {
				if(!msp.available)
					msp.close();
            });

		eol="\r";
        if(eolm == 1)
            eol="\n";
        else if(eolm == 2)
            eol="\r\n";
        else if(eolm == 3)
            eol="\r\r\n";

        MWPLog.set_time_format("%T");
		if(eolm > 1)
			MWPLog.set_cr();
		MWPLog.set_time_format("%T");
		if (dev == null) {
			if(DevManager.serials.length() == 1) {
				var dx = DevManager.serials.nth_data(0);
				if (dx.type == DevMask.USB) {
					dev = dx.name;
				}
			}
		}
        msp.cli_event.connect((buf,len) => {
                if(sendpass)
                    ml.quit();
                else
                    Posix.write(1,buf,len);
            });

		msp.serial_event.connect((cmd, buf, len, flags, err) => {
				if (!err && cmd == MSP.Cmds.FC_VERSION) {
					inavvers = buf[0];
					msp_init();
				}
			});

		msp.serial_lost.connect(() => {
				ml.quit();
			});

		if(!msp.available && dev != null) {
			string rdev;
			var st = DevUtils.evince_device_type(dev, out rdev);
			if(st == DevUtils.SerialType.BT || st == DevUtils.SerialType.UNKNOWN) {
				dev = rdev;
				DevManager.wait_device_async.begin(rdev, (obj,res) => {
						var ok = DevManager.wait_device_async.end(res);
						if (ok) {
							var dd = DevManager.get_dd_for_name(dev);
							if (dd != null) {
								dev = dd.name;
								if (DevUtils.valid_bt_name(dev)) {
									open_device(dev);
								}
							}
						} else {
							MWPLog.message("Unrecognised %s\n", dev);
							ml.quit();
						}
					});
			} else if (st != DevUtils.SerialType.UNKNOWN) {
				open_device(dev);
			} else {
				MWPLog.message("Unrecognised %s\n", dev);
				ml.quit();
			}
		}
    }

    private void replay_file() {
        FileStream fs = FileStream.open (rcfile, "r");
        if(fs != null) {
            Timeout.add(200, () => {
                    var s = fs.read_line();
                    if(s != null) {
                        if(s.has_prefix("#") == false && s._strip().length != 0) {
                            msp.write(s.data, s.length);
                            msp.write(eol.data, eol.length);
                        }
                        return true;
                    } else
                        return false;
                });
        }
    }

	private void msp_init() {
		oldmode  =  msp.pmode;
		msp.pmode = MWSerial.ProtoMode.CLI;
		if(noinit == false) {
			Timeout.add(50, () => {
					msp.write("#".data, 1);
					return false;
				});
			if(msc) {
				Timeout.add(500, () => {
						msp.write("msc".data, 3);
						msp.write(eol.data, eol.length);
						return false;
					});
			} else if(gpspass) {
				Timeout.add(500, () => {
						var g = "gpspassthrough";
						msp.write(g.data, g.length);
						msp.write(eol.data, eol.length);
						sendpass = true;
						return false;
					});
			} else if(rcfile != null) {
				Timeout.add(1000, () => {
						replay_file();
						return false;
					});
			} else {
				if(inavvers > 4 && cli_delay != 0)  {
					Timeout.add(500, () => {
							var clidelay = "cli_delay %d\r\n".printf(cli_delay);
							msp.write(clidelay.data, clidelay.length);
							return false;
						});
				}
			}
		}
	}

    private void open_device(string device) {
        print ("opening  %s ...\r\n",device);
		msp.open_async.begin(device, baud,  (obj,res) => {
				var ok = msp.open_async.end(res);
				if (ok) {
					msp.setup_reader();
					if(noinit) {
						msp.pmode = MWSerial.ProtoMode.CLI;
					} else {
						msp.pmode = MWSerial.ProtoMode.NORMAL;
						msp.send_command(MSP.Cmds.FC_VERSION, null,0);
						Timeout.add(2000,() => {
								if (msp.pmode != MWSerial.ProtoMode.CLI) {
									msp.pmode = MWSerial.ProtoMode.CLI;
								}
								return false;
							});
					}
				} else {
					string estr;
					msp.get_error_message(out estr);
					MWPLog.message("open failed %s\n", estr);
				}
			});
	}

    public void run() {
        Posix.termios newtio = {0};
        Posix.tcgetattr (0, out newtio);
        oldtio = newtio;
        Posix.cfmakeraw(ref newtio);
        Posix.tcsetattr(0, Posix.TCSANOW, newtio);

        try {
            var io_read = new IOChannel.unix_new(0);
            if(io_read.set_encoding(null) != IOStatus.NORMAL)
                error("Failed to set encoding");
			io_read.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL|IOCondition.ERR, (g,c) => {
				uint8 buf[2];
				ssize_t rc = -1;
				var err = ((c & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0);
				if (!err)
					rc = Posix.read(0, buf, 1);
				if (err || buf[0] == 3 || rc <0) {
					ml.quit();
					return false;
				}
				if (msp.available) {
					if(buf[0] == 13 && eolm != 0) {
						msp.write(eol.data,eol.length);
					} else {
						msp.write(buf,1);
					}
				}
				return true;
			});
		} catch(IOChannelError e) {
			error("IOChannel: %s", e.message);
		}

	}
	public void shutdown() {
		msp.close();
		Posix.tcsetattr(0, Posix.TCSANOW, oldtio);
	}

	public static string[]? set_def_args() {
		var fn = MWPUtils.find_conf_file("cliopts");
		if(fn != null) {
			var file = File.new_for_path(fn);
			try {
				var dis = new DataInputStream(file.read());
				string line;
				string []m;
				var sb = new StringBuilder ("cli");
				while ((line = dis.read_line (null)) != null) {
					if(line.strip().length > 0) {
						if (line.has_prefix("-")) {
							sb.append_c(' ');
							sb.append(line);
						}
					}
				}
				Shell.parse_argv(sb.str, out m);
				if (m.length > 1) {
					return m;
				}
			} catch (Error e) {
				error ("%s", e.message);
			}
		}
		return null;
	}

	public static int main (string[] args) {
		ml = new MainLoop();
		try {
			var opt = new OptionContext(" - cli tool");
			opt.set_help_enabled(true);
			opt.add_main_entries(options, null);
			var m = set_def_args();
			if (m != null) {
				opt.parse_strv(ref m);
			}
			opt.parse(ref args);
		} catch (OptionError e) {
			stderr.printf("Error: %s\n", e.message);
			stderr.printf("Run '%s --help' to see a full list of available "+
						  "options\n", args[0]);
			return 1;
		}

		if (args.length > 2)
			baud = int.parse(args[2]);

		if (args.length > 1)
			dev = args[1];

		switch (eolmstr) {
		case "cr":
			eolm = 0;
			break;
		case "lf":
			eolm = 1;
			break;
		case "crlf":
			eolm = 2;
			break;
        case "crcrlf":
            eolm = 3;
            break;
		}
		var cli = new CliTerm();
		Timeout.add(700, () => {
				cli.init();
				cli.run();
				return false;
			});
		ml.run();
		cli.shutdown();
		return 0;
	}
}
