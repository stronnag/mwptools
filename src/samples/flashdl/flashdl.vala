/*
 * Copyright (C) Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Flashdl : Object {
    private static int baud = 115200;
    private static string dev;
    private static string fname;
    private static string dname;
    private static bool erase = false;
    private static bool xerase = false;
    private static bool info = false;
    private static bool test = false;

    const OptionEntry[] options = {
        { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", null},
        { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
        { "output", 'o', 0, OptionArg.STRING, out fname, "file name", null},
        { "outout-dir", 'O', 0, OptionArg.STRING, out dname, "dir name", null},
        { "erase", 'e', 0,  OptionArg.NONE, out erase, "erase on completion", null},
        { "only-erase", 0, 0,  OptionArg.NONE, out xerase, "erase only", null},
        { "info", 'i', 0,  OptionArg.NONE, out info, "just show info", null},
        { "test", 't', 0,  OptionArg.NONE, out test, "download whole flash", null},
        {null}
    };

    public DevManager dmgr;
    private static MainLoop ml;
    private MWSerial msp;
    private uint32 bread = 0;
    private uint32 used;
    private uint32 fsize;
    private FileStream fp;
    private string efsize;
    private bool echeck = false;

    time_t st;
    time_t et;


    Flashdl() {
        MwpTermCap.init();
    }

    private void handle_serial(Msp.Cmds cmd, uint8[] raw, uint len, uint8 xflags, bool errs) {
         if(errs == true) {
             if (cmd == Msp.Cmds.BLACKBOX_CONFIG)
                 MWPLog.message("No dataflash\n");
             else
                 MWPLog.message("Error on cmd %s %d\n", cmd.to_string(), cmd);
             ml.quit();
         }

         switch(cmd) {
             case Msp.Cmds.FC_VARIANT:
                 var fc_var = (string)raw[0:4];
                 switch(fc_var) {
                     case "CLFL":
                     case "BTFL":
                     case "INAV":
                         msp.send_command(Msp.Cmds.API_VERSION,null,0);
                     break;
                     default:
                         MWPLog.message("Unsupported FC\n");
                         ml.quit();
                         break;
                 }
                 break;

             case Msp.Cmds.API_VERSION:
                 uint16 fc_api = raw[1] << 8 | raw[2];
                 if (fc_api >=0x0200)
                     msp.use_v2 = true;
                 msp.send_command(Msp.Cmds.BLACKBOX_CONFIG,null,0);
                break;

            case Msp.Cmds.BLACKBOX_CONFIG:
            case Msp.Cmds.BLACKBOX_CONFIGv2:
//                print("Config %x %u %u %u\n", cmd, len, raw[0], raw[1]);
                if (raw[0] == 1 && raw[1] == 1)  // enabled and sd flash
                    if(xerase)
                        msp.send_command(Msp.Cmds.DATAFLASH_ERASE,null,0);
                    else
                        msp.send_command(Msp.Cmds.DATAFLASH_SUMMARY,null,0);
                else {
                    if (cmd == Msp.Cmds.BLACKBOX_CONFIGv2) {
                        MWPLog.message("No dataflash %u\n", cmd);
                        ml.quit();
                    }
                    msp.send_command(Msp.Cmds.BLACKBOX_CONFIGv2,null,0);
                }
                break;

            case Msp.Cmds.DATAFLASH_SUMMARY:
                var isready = raw[0];
                if(echeck) {
                    if(isready == 1) {
                        MWPLog.message("Completed\n");
                        ml.quit();
                    } else
                        schedule_echeck();
                } else {
                    SEDE.deserialise_u32(raw+5, out fsize);
                    SEDE.deserialise_u32(raw+9, out used);

                    if(test) {
                        string s2=null;
                        if((s2 = Environment.get_variable("TEST_USED")) != null)
                           used = int.parse(s2);
                        else
                            used =fsize;
                        MWPLog.message("Entering test mode for %s\n", esize(used));
                    }
                    var pct = 100 * used  / fsize;
                    MWPLog.message ("Data Flash %u /  %u (%u%%)\n", used, fsize, pct);
                    if(used == 0 || info)
                        ml.quit();
                    else {
                        efsize = esize(used);
                        time_t(out st);
                        if(fname == null)
							dt = new DateTime.from_unix_local(st);
                            fname  = "BBL_%s.TXT".printf(dt.format("%F_%H%M%S"));
                        if (dname != null) {
                            if(!FileUtils.test (dname, FileTest.EXISTS))
                                DirUtils.create_with_parents (dname, 0755);
                            fname = Path.build_filename (dname, fname);
                        }

                        fp = FileStream.open (fname, "w");
                        if(fp == null) {
                            MWPLog.message("Failed to open file [%s]\n".printf(fname));
                            ml.quit();
                        } else
                            MWPLog.message("Downloading to %s\n".printf(fname));

                        send_data_read(0, ((used > 4096) ? 4096 : (uint16)used));
                        stderr.printf("%s", MwpTermCap.civis);
                    }
                }
                break;

             case Msp.Cmds.DATAFLASH_READ:
                 uint32 newaddr;
                 SEDE.deserialise_u32(raw, out newaddr);
                 var dlen = len - 4;
                 fp.write(raw[4:len]);
                 bread += dlen;
                 var rate = get_rate();
                 var remtime = (used - bread) / rate;
                 var pct = 100 * bread / used;
                 var sb = new StringBuilder();
                 int i;
                 for(i = 0; i < 50; i++)
                     if(i < pct*50/100)
                         sb.append_unichar(0x2587);
                     else
                         sb.append_unichar(' ');

                 stderr.printf("\r[%s] %s/%s %3u%% %us%s", sb.str,
                               esize(bread),
                               efsize,
                               pct,
                               remtime, MwpTermCap.ceol);

                 var rem  = used - bread;
                 if (rem > 0) {
                     send_data_read(bread, (rem > 4096) ? 4096 : (uint16)rem);
                 } else {
                     stderr.printf("%s\n", MwpTermCap.cnorm);
                     MWPLog.message("%u bytes in %us, %u bytes/s\n", bread, (et-st), rate);
                     if (erase) {
                         MWPLog.message("Start erase\n");
                         msp.send_command(Msp.Cmds.DATAFLASH_ERASE,null,0);
                     } else
                         ml.quit();
                 }
                 break;
             case Msp.Cmds.DATAFLASH_ERASE:
                 MWPLog.message("Erase in progress ... \n");
                 schedule_echeck();
                 break;
             default:
                 break;
         }
    }

    private void schedule_echeck() {
        echeck = true;
        Timeout.add(1000, () => {
                msp.send_command(Msp.Cmds.DATAFLASH_SUMMARY,null,0);
                return Source.REMOVE;
            });
    }

    private string esize(uint32 v) {
        string s;

        if(v < 1024)
            s = "%uB".printf(v);
        else {
            double d = v;
            d /= 1024.0;
            if (d < 1024)
                s = "%.1fKB".printf(d);
            else {
                d /= 1024.0;
                s = "%.1fMB".printf(d);
            }
        }
        return s;
    }

    private uint32 get_rate() {
        time_t(out et);
        uint32 rate;
        var dt = (et - st);
        if(dt == 0)
            rate = baud / 10;
        else
            rate = bread/ (uint32)dt;
        return rate;
    }

    private void send_data_read(uint32 addr, uint16 needed) {
        uint8 buf[6];
        SEDE.serialise_u32(buf, addr);
        SEDE.serialise_u16(&buf[4], needed);
        msp.send_command(Msp.Cmds.DATAFLASH_READ,buf, 6);
    }

    private void init() {
        MWPLog.set_time_format("%T");
        ml = new MainLoop();
        msp = new MWSerial();
        dmgr = new DevManager();

        dmgr.device_added.connect((sdev) => {
				if(!msp.available && sdev.type == DevMask.USB) {
					open_device(sdev.name);
				}
            });

        dmgr.device_removed.connect((sdev) => {
                msp.close();
            });

        msp.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
                handle_serial(cmd, raw, len, xflags, errs);
            });

        msp.serial_lost.connect(() => {
                msp.close();
                ml.quit();
            });

        Unix.signal_add(ProcessSignal.INT, () => {
					Timeout.add(100, () => {
							stderr.printf("%s\n", MwpTermCap.cnorm);
							ml.quit();
							return Source.REMOVE;
						});
					return Source.REMOVE;
            });

		if(dev == null) {
			if(DevManager.serials.length() == 1) {
				var dx = DevManager.serials.nth_data(0);
				if (dx.type == DevMask.USB) {
					dev = dx.name;
				}
			}
		}

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

    private void open_device(string d) {
        if(!msp.available) {
			msp.open_async.begin(d, baud,  (obj,res) => {
					var ok = msp.open_async.end(res);
					if (ok) {
						msp.setup_reader();
						Timeout.add(250, () => {
								msp.send_command(Msp.Cmds.FC_VARIANT, null, 0);
								return Source.REMOVE;
							});
						MWPLog.message("Opened %s\n", d);
					} else {
						string estr;
						msp.get_error_message(out estr);
						MWPLog.message("open failed %s\n", estr);
					}
				});
		}
    }

    private void run() {
        ml.run ();
    }

    public static int main (string[] args) {
        try {
            var opt = new OptionContext(" - iNav Flash download / erase");
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
            opt.parse(ref args);
        } catch (OptionError e) {
            stderr.printf("Error: %s\n", e.message);
            stderr.printf("Run '%s --help' to see a full list of available "+
                          "options\n", args[0]);
            return 1;
        }

        if (args.length > 3)
            fname = args[3];

        if (args.length > 2)
            baud = int.parse(args[2]);

        if (args.length > 1)
            dev = args[1];

        var f = new Flashdl();
        f.init();
        f.run();
        return 0;
    }
}
