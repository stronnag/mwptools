
private static int baud = 115200;
private static string eolmstr;
private static string dev;
private static bool noinit=false;
private static string rcfile=null;
private static int eolm;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", "115200"},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
    { "noinit", 'n', 0,  OptionArg.NONE, out noinit, "noinit", "false"},
    { "file", 'f', 0, OptionArg.STRING, out rcfile, "file", null},
    { "eolmode", 'm', 0, OptionArg.STRING, out eolmstr, "eol mode", "[cr,lf,crlf,crcrlf]"},
    {null}
};

class CliTerm : Object
{
    private MWSerial msp;
    private MWSerial.ProtoMode oldmode;
    public DevManager dmgr;
    private MainLoop ml;
    private string eol;

    public void init()
    {
        eol="\r";
        if(eolm == 1)
            eol="\n";
        else if(eolm == 2)
            eol="\r\n";
        else if(eolm == 3)
            eol="\r\r\n";

        MWPLog.set_time_format("%T");
        ml = new MainLoop();
        msp= new MWSerial();
        dmgr = new DevManager(DevMask.USB);

        var devs = dmgr.get_serial_devices();
        if(dev == null && devs.length == 1)
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

        msp.cli_event.connect((buf,len) => {
                    Posix.write(1,buf,len);
                });

        msp.serial_lost.connect(() => {
                    ml.quit();
                });
    }

    private void replay_file()
    {
        FileStream fs = FileStream.open (rcfile, "r");
        if(fs != null)
        {
            Timeout.add(200, () => {
                    var s = fs.read_line();
                    if(s != null)
                    {
                        if(s.has_prefix("#") == false && s._strip().length != 0)
                        {
                            msp.write(s.data, s.length);
                            msp.write(eol.data, eol.length);
                        }
                        return true;
                    }
                    else
                        return false;
                });
        }
    }

    private void open_device(string device)
    {
        string estr;
        print ("open %s\r\n",device);
        if(msp.open(device, baud, out estr) == true)
        {
            oldmode  =  msp.pmode;
            msp.pmode = MWSerial.ProtoMode.CLI;
            if(noinit == false)
                Timeout.add(250, () => {
                        msp.write("#".data, 1);
                        return false;
                    });
            if(rcfile != null)
            {
                Timeout.add(1000, () => {
                        replay_file();
                        return false;
                    });
            }
        }
        else
        {
            print("open failed %s\r\n", estr);
        }
    }

    public void run()
    {

        Posix.termios newtio = {0}, oldtio = {0};
        Posix.tcgetattr (0, out newtio);
        oldtio = newtio;
        Posix.cfmakeraw(ref newtio);
        Posix.tcsetattr(0, Posix.TCSANOW, newtio);

        try {
            var io_read = new IOChannel.unix_new(0);
            if(io_read.set_encoding(null) != IOStatus.NORMAL)
                error("Failed to set encoding");
            io_read.add_watch(IOCondition.IN|IOCondition.HUP|
                              IOCondition.NVAL|IOCondition.ERR,
                              (g,c) => {
                                  uint8 buf[2];
                                  ssize_t rc = -1;
                                  var err = ((c & (IOCondition.HUP|
                                                   IOCondition.ERR|
                                                   IOCondition.NVAL)) != 0);
                                  if(!err)
                                      rc = Posix.read(0,buf,1);

                                  if(err || buf[0] == 3 || rc <0)
                                  {
                                      ml.quit();
                                      return false;
                                  }

                                  if(buf[0] == 13 && eolm != 0)
                                  {
                                      msp.write(eol.data,eol.length);
                                  }
                                  else
                                      msp.write(buf,1);
                                  return true;
                              });
        } catch(IOChannelError e) {
            error("IOChannel: %s", e.message);
        }
        ml.run ();
        msp.close();
        Posix.tcsetattr(0, Posix.TCSANOW, oldtio);
    }
}

int main (string[] args)
{
    try {
        var opt = new OptionContext(" - cli tool");
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

    if (args.length > 2)
        baud = int.parse(args[2]);

    if (args.length > 1)
        dev = args[1];

    switch (eolmstr)
    {
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
    cli.init();
    cli.run();

    return 0;
}