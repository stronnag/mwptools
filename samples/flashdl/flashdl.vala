public class Flashdl : Object
{
    private static int baud = 115200;
    private static string dev;
    private static string fname;
    private static bool erase = false;
    private static bool xerase = false;
    private static bool info = false;

    const OptionEntry[] options = {
        { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", null},
        { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
        { "outout", 'o', 0, OptionArg.STRING, out fname, "file name", null},
        { "erase", 'e', 0,  OptionArg.NONE, out erase, "erase on completion", null},
        { "only-erase", 'E', 0,  OptionArg.NONE, out xerase, "erase only", null},
        { "info", 'i', 0,  OptionArg.NONE, out info, "just show info", null},
        {null}
    };

    private static MainLoop ml;
    private MWSerial s;
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
        ml = new MainLoop();
        s = new MWSerial();
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
                         s.send_command(MSP.Cmds.API_VERSION,null,0);
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
                     s.use_v2 = true;
                 s.send_command(MSP.Cmds.BLACKBOX_CONFIG,null,0);
                break;

            case MSP.Cmds.BLACKBOX_CONFIG:
                if (raw[0] == 1 && raw[1] == 1)  // enabled and sd flash
                    if(xerase)
                        s.send_command(MSP.Cmds.DATAFLASH_ERASE,null,0);
                    else
                        s.send_command(MSP.Cmds.DATAFLASH_SUMMARY,null,0);
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
                    efsize = esize(fsize);
                    var pct = 100 * used  / fsize;
                    MWPLog.message ("Data Flash %u /  %u (%u%%)\n", used, fsize, pct);
                    if(used == 0 || info)
                        ml.quit();
                    else
                    {
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
                 var pct = 100 * bread / fsize;
                 var sb = new StringBuilder();
                 int i;
                 for(i = 0; i < 50; i++)
                     if(i < pct/2)
                         sb.append_unichar('█');
                     else
                         sb.append_unichar(' ');

                 var str = "[%s] %s/%s %3u%% %us    \r".printf(sb.str, esize(bread), efsize,
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
                     MWPLog.message("%u bytes in %u s, %u b/s\n", bread, (et-st), rate);
                     if (erase)
                     {
                         MWPLog.message("Start erase\n");
                         s.send_command(MSP.Cmds.DATAFLASH_ERASE,null,0);
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
                s.send_command(MSP.Cmds.DATAFLASH_SUMMARY,null,0);
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
        s.send_command(MSP.Cmds.DATAFLASH_READ,buf, 6);
    }

    private int run()
    {
        string estr;
        bool res;

        Posix.signal (Posix.SIGINT, (s) => {
                Timeout.add(100, () => {
                        ml.quit();
                        return Source.REMOVE;
                    });
            });

        if((res = s.open(dev, baud, out estr)) == true)
        {
            s.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
                    handle_serial(cmd, raw, len, xflags, errs);
                });

            s.serial_lost.connect(() => {
                    s.close();
                    ml.quit();
                });

            Timeout.add(250, () => {
                    s.send_command(MSP.Cmds.FC_VARIANT, null, 0);
                    return Source.REMOVE;
                });

            ml.run ();
            return 0;
        }
        else
        {
            MWPLog.message("open failed serial %s %s\n", dev, estr);
            return 255;
        }
    }

    public static int main (string[] args)
    {
        string []devs = {"/dev/ttyUSB0","/dev/ttyACM0"};
        foreach(var d in devs)
        {
            if(Posix.access(d,(Posix.R_OK|Posix.W_OK)) == 0)
            {
                dev = d;
                break;
            }
        }

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

        if(dev == null)
        {
            stdout.puts("No device found\n");
            return 0;
        }
        return new Flashdl().run();
    }
}
