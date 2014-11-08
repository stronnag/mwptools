
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
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
 */


/* Upload a cleanflight CLI dump back into a naze32 FC */


public class MWSerial : Object
{
    public int fd {private set; get;}
    private IOChannel io_read;
    public  bool available {private set; get;}
    private uint tag;
    private Posix.termios oldtio;
    public uint baudrate  {private set; get;}
    public DataInputStream dis;
    public OutputStream os;
    public uint8 rx_mode;
    public uint8 nlcount = 0;

    private static string defname;
    private static string devname;
    private static int brate;
    const OptionEntry[] options = {
        { "device", 'd', 0, OptionArg.STRING, out devname, "device name", null},
        { "output-file", 'o', 0, OptionArg.STRING, out defname, "output file name", null},
        { "baudrate", 'b', 0, OptionArg.INT, out brate, "Baud rate", null},
        {null}
    };


    public signal void completed();

    public MWSerial()
    {
        available = false;
        fd = -1;
        if(devname == null)
            devname = "/dev/ttyUSB0";
        stderr.printf("open %s %d\n", devname, brate);
        this.open(devname,brate);
    }

    private void setup_fd (uint rate)
    {
        baudrate = rate;
        Posix.termios newtio = {0};
        Posix.speed_t posix_baudrate;

        switch(rate) {
            case 1200:
                posix_baudrate = Posix.B1200;
                break;
            case 2400:
                posix_baudrate = Posix.B2400;
                break;
            case 4800:
                posix_baudrate = Posix.B4800;
                break;
            case 9600:
                posix_baudrate = Posix.B9600;
                break;
            case 19200:
                posix_baudrate = Posix.B19200;
                break;
            case 38400:
                posix_baudrate = Posix.B38400;
                break;
            case 57600:
                posix_baudrate = Posix.B57600;
                break;
            case 115200:
            case 0:
                posix_baudrate = Posix.B115200;
                break;
            case 230400:
                posix_baudrate = Posix.B230400;
                break;
            default:
                posix_baudrate = Posix.B115200;
                break;
        }

        Posix.tcgetattr (fd, out newtio);
        oldtio = newtio;

        Posix.cfmakeraw(ref newtio);
        newtio.c_cc[Posix.VTIME]=0;
        newtio.c_cc[Posix.VMIN]=0;
        Posix.cfsetospeed(ref newtio, posix_baudrate);
        Posix.cfsetispeed(ref newtio, posix_baudrate);
        Posix.tcsetattr(fd, Posix.TCSANOW, newtio);
        available = true;
        setup_reader(fd);
    }

    private void setup_reader(int fd)
    {
        try {
            io_read = new IOChannel.unix_new(fd);
            if(io_read.set_encoding(null) != IOStatus.NORMAL)
                    error("Failed to set encoding");
            tag = io_read.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL,
                                    device_read);
        } catch(IOChannelError e) {
            error("IOChannel: %s", e.message);
        }
    }


    public bool open(string device, uint rate)
    {
        string [] parts;

        parts = device.split ("@");
        if(parts.length == 2)
        {
            device = parts[0];
            rate = int.parse(parts[1]);
        }
        fd = Posix.open(device, Posix.O_RDWR);
        setup_fd((int)rate);
        if(fd < 0)
        {
            var lasterr=Posix.errno;
            var s = Posix.strerror(lasterr);
            stderr.printf("%s (%d)\n", s, lasterr);
            fd = -1;
            available = false;
        }
        else
        {
            available = true;
            setup_reader(fd);
        }
        return available;
    }

    public bool open_fd(int _fd, int rate)
    {
        fd = _fd;
        setup_fd(rate);
        return available;
    }

    ~MWSerial()
    {
        if(fd != -1)
            close();
    }

    public void close()
    {
        available=false;
        if(fd != -1)
        {
            if(tag > 0)
            {
                Source.remove(tag);
            }
            try  { io_read.shutdown(false); } catch {}
            Posix.tcsetattr (fd, Posix.TCSANOW|Posix.TCSADRAIN, oldtio);
            Posix.close(fd);
            fd = -1;
        }
    }

    private bool device_read(IOChannel gio, IOCondition cond) {
        uint8 buf[128];
        size_t res;
        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0)
        {
            available = false;
            return false;
        }
        else
        {
            res = Posix.read(fd,buf,128);
            if(res == 0)
                return true;
        }

        if (rx_mode == 1)
        {
            uint8[] rbuf;
            if(nlcount == 0)
            {
                stderr.write(buf[0:4]);
                if (buf[0] == 'd' && buf[1] == 'u' && buf[2] == 'm' &&
                    buf[3] == 'p')
                {
                    rbuf = buf[4:res];
                }
                else
                {
                    rbuf = buf[0:res];
                }
            }
            else
                rbuf = buf[0:res];

            try
            {
                os.write(rbuf);
            } catch  {}

            for(var nc = 0; nc < res; nc++)
            {
                if (buf[nc] == '\n' || buf[nc] == '\r')
                    nlcount++;
            }
        }

        for(var nc = 0; nc < res; nc++)
        {
            stdout.putc((char)buf[nc]);
            stdout.flush();
             if(buf[nc] == '#' && rx_mode == 2 && dis != null)
             {
                 Timeout.add(100, () =>  { xmit_file(); return false; });
             }
        }
        return true;
    }

    private void setfile (DataInputStream _dis)
    {
        dis = _dis;
    }

    private void setdump (OutputStream _os)
    {
        os = _os;
    }

    private void xmit_file()
    {
        bool done = false;
        while(!done)
        {
            string rline;
            try
            {
                rline = dis.read_line (null);
            } catch (Error e) {
                rline = null;
                stderr.printf("read error %s\n", e.message);
            }

            if(rline == null)
            {
                Posix.write(fd,"exit\n", 5);
                try { dis.close(); } catch {}
                dis = null;
                done = true;
                Timeout.add_seconds(1,() => { completed(); return false; });
            }
            else
            {
                var line = rline.strip();
                if(line.length > 0 && line[0] != '#')
                {
                    if (line.length > 5 && line.substring(0,5) == "Clean")
                    {
                        stderr.printf("skip %s\n", line);
                    }
                    else
                    {
                        Posix.write(fd, line, line.length);
                        Posix.write(fd,"\n", 1);
                        done = true;
                    }
                }
            }
        }
    }

    public static int main (string[] args)
    {
        try {
            var opt = new OptionContext("cleanflight_dump_file");
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

        DataInputStream mdis = null;
        OutputStream mos = null;

        if(args.length > 1)
        {
            var file = File.new_for_path (args[1]);
            if (!file.query_exists ())
            {
                stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
                return 255;
            }
            else
            {
                try
                {
                    mdis = new DataInputStream (file.read ());
                } catch (Error e) {
                    stderr.printf ("Bizarre error %s\n", e.message);
                    return 255;
                }
            }
        }

        var s = new MWSerial();
        var ml = new MainLoop();
        s.rx_mode = -1;
        IOStream ios;

        s.completed.connect(() => {ml.quit();});

        time_t currtime;
        time_t(out currtime);
        string fn;
        if(defname == null)
            fn  = "naze_%s.txt".printf(Time.local(currtime).format("%F_%H%M%S"));
        else
            fn = defname;

        try
        {
            var file = File.new_for_path (fn);
            ios = file.create_readwrite (FileCreateFlags.PRIVATE);
            mos = ios.output_stream;
            s.setdump(mos);
        } catch (Error e) {
            stderr.printf ("Logger: %s %s\n", fn, e.message);
        }

        Timeout.add(100, () => {
                Posix.write(s.fd,"#", 1);
                return false;
            });

        Timeout.add(300, () => {
                s.rx_mode = 1;
                s.nlcount = 0;
                var str = "dump\n";
                Posix.write(s.fd,str, str.length);
                return false;
            });

        if(mdis == null)
        {
            Timeout.add(1000, () => {
                s.rx_mode = -1;
                s.nlcount = -1;
                var str = "exit\n";
                Posix.write(s.fd,str, str.length);
                Timeout.add_seconds(1,() => { ml.quit(); return false; });
                return false;
            });
        }
        else
        {
            Timeout.add(2000, () => {
                    s.rx_mode = -1;
                    var str = "defaults\n";
                    Posix.write(s.fd,str, str.length);
                    return false;
                });

            Timeout.add(15000, () => {
                    s.rx_mode = 2;
                    s.setfile(mdis);
                    Posix.write(s.fd,"#", 1);
//                    s.xmit_file();
                    return false;
                });
        }
        ml.run();

        try { mos.close(); } catch {}

        stdout.puts("\n");
        return 0;
    }
}
