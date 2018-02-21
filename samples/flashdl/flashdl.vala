public class Flashdl : Object
{
    private static int baud = 115200;
    private static string dev;
    private static string fname;
    private static bool erase = false;
    private static bool xerase = false;
    private static bool info = false;
    private static bool test = false;

    const OptionEntry[] options = {
        { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", null},
        { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
        { "outout", 'o', 0, OptionArg.STRING, out fname, "file name", null},
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

    Flashdl()
    {
    }

    private void handle_serial(MSP.Cmds cmd, uint8[] raw, uint len, uint8 xflags, bool errs)
    {
         if(errs == true)
         {
             MWPLog.message("Error on cmd %s %d\n", cmd.to_string(), cmd);
             ml.quit();
         }

         switch(cmd)
         {
             case MSP.Cmds.FC_VARIANT:
                 var fc_var = (string)raw[0:4];
                 switch(fc_var)
                 {
                     case "CLFL":
                     case "BTFL":
                     case "INAV":
                         msp.send_command(MSP.Cmds.API_VERSION,null,0);
                     break;
                     default:
                         MWPLog.message("Unsupported FC\n");
                         ml.quit();
                         break;
                 }
                 break;

             case MSP.Cmds.API_VERSION:
                 uint16 fc_api = raw[1] << 8 | raw[2];
                 if (fc_api >=0x0200)
                     msp.use_v2 = true;
                 msp.send_command(MSP.Cmds.BLACKBOX_CONFIG,null,0);
                break;

            case MSP.Cmds.BLACKBOX_CONFIG:
                if (raw[0] == 1 && raw[1] == 1)  // enabled and sd flash
                    if(xerase)
                        msp.send_command(MSP.Cmds.DATAFLASH_ERASE,null,0);
                    else
                        msp.send_command(MSP.Cmds.DATAFLASH_SUMMARY,null,0);
                else
                {
                    MWPLog.message("No dataflash\n");
                    ml.quit();
                }
                break;

            case MSP.Cmds.DATAFLASH_SUMMARY:
                var isready = raw[0];
                if(echeck)
                {
                    if(isready == 1)
                    {
                        MWPLog.message("Completed\n");
                        ml.quit();
                    }
                    else
                        schedule_echeck();
                }
                else
                {
                    deserialise_u32(raw+5, out fsize);
                    deserialise_u32(raw+9, out used);
                    var pct = 100 * used  / fsize;
                    MWPLog.message ("Data Flash %u /  %u (%u%%)\n", used, fsize, pct);
                    if(test)
                    {
                        used =fsize;
                        MWPLog.message("Entering test mode\n");
                    }

                    if(used == 0 || info)
                        ml.quit();
                    else
                    {
                        efsize = esize(used);
                        time_t(out st);
                        if(fname == null)
                            fname  = "BBL_%s.TXT".printf(Time.local(st).format("%F_%H%M%S"));
                        fp = FileStream.open (fname, "w");
                        if(fp == null)
                        {
                            MWPLog.message("Failed to open file [%s]\n".printf(fname));
                            ml.quit();
                        }
                        else
                            MWPLog.message("Downloading to %s\n".printf(fname));

                        send_data_read(0, ((used > 4096) ? 4096 : (uint16)used));
                    }
                }
                break;

             case MSP.Cmds.DATAFLASH_READ:
                 uint32 newaddr;
                 deserialise_u32(raw, out newaddr);
                 var dlen = len - 4;
                 fp.write(raw[4:len]);
                 bread += dlen;
                 var rate = get_rate();
                 var remtime = (used - bread) / rate;
                 var pct = 100 * bread / used;
                 var sb = new StringBuilder();
                 int i;
                 for(i = 0; i < 50; i++)
                     if(i < pct/2)
                         sb.append_unichar('█');
                     else
                         sb.append_unichar(' ');

                 var str = "\r[%s] %s/%s %3u%% %us    ".printf(sb.str, esize(bread), efsize,
                                                                   pct, remtime);
                 Posix.write(2, str, str.length);

                 var rem  = used - bread;
                 if (rem > 0)
                 {
                     send_data_read(bread, (rem > 4096) ? 4096 : (uint16)rem);
                 }
                 else
                 {
                     print("\n");
                     MWPLog.message("%u bytes in %us, %u bytes/s\n", bread, (et-st), rate);
                     if (erase)
                     {
                         MWPLog.message("Start erase\n");
                         msp.send_command(MSP.Cmds.DATAFLASH_ERASE,null,0);
                     }
                     else
                         ml.quit();
                 }
                 break;
             case MSP.Cmds.DATAFLASH_ERASE:
                 MWPLog.message("Erase in progress ... \n");
                 schedule_echeck();
                 break;
         }
    }

    private void schedule_echeck()
    {
        echeck = true;
        Timeout.add(1000, () => {
                msp.send_command(MSP.Cmds.DATAFLASH_SUMMARY,null,0);
                return Source.REMOVE;
            });
    }

    private string esize(uint32 v)
    {
        string s;

        if(v < 1024)
            s = "%uB".printf(v);
        else
        {
            double d = v;
            d /= 1024.0;
            if (d < 1024)
                s = "%.1fKB".printf(d);
            else
            {
                d /= 1024.0;
                s = "%.1fMB".printf(d);
            }
        }
        return s;
    }

    private uint32 get_rate()
    {
        time_t(out et);
        uint32 rate;
        var dt = (et - st);
        if(dt == 0)
            rate = baud / 10;
        else
            rate = bread/ (uint32)dt;
        return rate;
    }

    private void send_data_read(uint32 addr, uint16 needed)
    {
        uint8 buf[6];
        serialise_u32(buf, addr);
        serialise_u16(buf+4, needed);
        msp.send_command(MSP.Cmds.DATAFLASH_READ,buf, 6);
    }

    private void init()
    {
        MWPLog.set_time_format("%T");
        ml = new MainLoop();
        msp = new MWSerial();
        dmgr = new DevManager(DevMask.USB);

        var devs = dmgr.get_serial_devices();
        if(devs.length == 1)
            dev = devs[0];

        if(dev != null)
            open_device(dev);

        dmgr.device_added.connect((sdev) => {
                if(!msp.available)
                    open_device(sdev);
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

        Posix.signal (Posix.SIGINT, (s) => {
                Timeout.add(100, () => {
                        ml.quit();
                        return Source.REMOVE;
                    });
            });
    }

    private void open_device(string d)
    {
        if(!msp.available)
        {
            string estr;
            if(msp.open(d, baud, out estr) == true)
            {
                MWPLog.message("Opened %s\n", d);
                Timeout.add(250, () => {
                        msp.send_command(MSP.Cmds.FC_VARIANT, null, 0);
                        return Source.REMOVE;
                    });
            }
            else
            {
                MWPLog.message("open failed %s\n", estr);
            }
        }
    }

    private void run()
    {
        ml.run ();
    }

    public static int main (string[] args)
    {
        try {
            var opt = new OptionContext(" - iNav Flash eraser");
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
            opt.parse(ref args);
        }
        catch (OptionError e) {
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
