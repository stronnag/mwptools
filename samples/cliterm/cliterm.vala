int main (string[] args)
{

    var ml = new MainLoop();
    MWSerial s;
    MWSerial.ProtoMode oldmode;

    s = new MWSerial();
    string estr;
    bool res;
    string []devs = {"/dev/ttyUSB0","/dev/ttyACM0"};
    string dev = null;

    int baud = 115200;

    foreach(var d in devs)
    {
        if(Posix.access(d,(Posix.R_OK|Posix.W_OK)) == 0)
        {
            dev = d;
            break;
        }
    }


    if (args.length > 2)
        baud = int.parse(args[2]);

    if (args.length > 1)
        dev = args[1];

    if(dev == null)
    {
        stdout.puts("No device found\n");
        return 0;
    }

    if((res = s.open(dev, baud, out estr)) == true)
    {
        oldmode  =  s.pmode;
        s.pmode = MWSerial.ProtoMode.CLI;
        s.cli_event.connect((buf,len) => {
                Posix.write(1,buf,len);
            });
        s.write("#\n".data, 2);
        s.serial_lost.connect(() => {
                s.close();
                ml.quit();
            });
    }
    else
    {
        MWPLog.message("open failed serial %s %s\n", dev, estr);
        return 255;
    }

    Posix.termios newtio = {0}, oldtio = {0};
    Posix.tcgetattr (1, out newtio);
    oldtio = newtio;
    Posix.cfmakeraw(ref newtio);
    Posix.tcsetattr(1, Posix.TCSANOW, newtio);

    try {
        var io_read = new IOChannel.unix_new(1);
        if(io_read.set_encoding(null) != IOStatus.NORMAL)
            error("Failed to set encoding");
        io_read.add_watch(IOCondition.IN|IOCondition.HUP|
                                IOCondition.NVAL|IOCondition.ERR,
                                    (g,c) => {
                                    uint8 buf[2];
                                    ssize_t rc = -1;
                                    var err = ((c & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0);
                                    if(!err)
                                        rc = Posix.read(0,buf,1);
                                    if(err || buf[0] == 3 || rc <0)
                                    {
                                        ml.quit();
                                        return false;
                                    }
                                    s.write(buf,1);
                                    return true;
                                });
    } catch(IOChannelError e) {
        error("IOChannel: %s", e.message);
    }
    ml.run ();
    Posix.tcsetattr(1, Posix.TCSANOW, oldtio);
    return 0;
}