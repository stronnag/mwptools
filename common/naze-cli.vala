
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
    public enum STATE
    {
        none=0,
        hash=1,
        done=2,
        do_reboot = 3,
        reboot = 4,
        restart = 5,
        setconfig = 6,
        zero = 127, // well, almost
        timeout = 128,
        end=255
    }

    public int fd {private set; get;}
    private IOChannel io_read;
    public  bool available {private set; get;}
    private uint tag;
    private Posix.termios oldtio;
    public uint baudrate  {private set; get;}
    public unowned FileStream dis;
    public unowned FileStream os;
    public uint8 rx_mode;
    public uint8 nlcount = 0;

    private static string defname;
    private static string devname;
    private static int brate;
    private static int profile = 0;
    private static int tprofile = 0;
    const OptionEntry[] options = {
        { "device", 'd', 0, OptionArg.STRING, out devname, "device name", null},
        { "output-file", 'o', 0, OptionArg.STRING, out defname, "output file name", null},
        { "baudrate", 'b', 0, OptionArg.INT, out brate, "Baud rate", null},
        { "profile", 'p', 0, OptionArg.INT, out profile, "Profile (0-2)", null},
        { "to-profile", 'P', 0, OptionArg.INT, out tprofile, "Profile (0-2)", null},
        {null}
    };

    public STATE state;
    public signal void completed();
    public signal void changed_state(STATE sx);
    private uint8 lbuf[256];
    public uint8 lidx = 0;
    private uint iotid;

    public MWSerial()
    {
        state = STATE.none;
        available = false;
        fd = -1;
        if(devname == null)
            devname = "/dev/ttyUSB0";
        MWPLog.message("open %s %d\n", devname, brate);
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
            tag = io_read.add_watch(IOCondition.IN|IOCondition.HUP|
                                    IOCondition.NVAL|IOCondition.ERR,
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
            MWPLog.message("%s (%d)\n", s, lasterr);
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

        if(iotid > 0)
        {
            Source.remove(iotid);
            iotid = 0;
        }

        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0)
        {
            stderr.puts("Error cond\n");
            available = false;
            return false;
        }
        else
        {
            res = Posix.read(fd,buf,128);
            if(res == 0)
            {
                if(rx_mode == 1)
                    start_serial_timer();

                if(state == STATE.do_reboot && lbuf[0] == '#')
                {
                    changed_state(STATE.reboot);
                }

                return true;
            }
        }

        if(state == STATE.none)
        {
            changed_state(STATE.hash);
        }

        if(state == STATE.restart)
        {
            changed_state(STATE.setconfig);
            return true;
        }

        for (var nc = 0; nc < res; nc++)
        {
            switch(buf[nc])
            {
                case '\n':
                case '\r':
                    lbuf[lidx] = '\0';
                    if(rx_mode == 1)
                    {
                        if(lidx > 1)
                        {
                            if(((string)lbuf).contains("Cleanflight"))
                            {
                                stdout.puts("# ");
                                os.puts("# ");
                            }
                            if(((string)lbuf).contains("Entering CLI ") == false)
                            {
                                stdout.printf("%s\n", (string)lbuf);
                                os.printf("%s\n", (string)lbuf);
                                os.flush();
                            }
                        }
                    }
                    else if(rx_mode == 2 && dis != null)
                    {
                        if(lidx > 1)
                            stdout.printf("%s\n", (string)lbuf);
                        if(lbuf[0] == '#')
                            Timeout.add(50, () =>  { xmit_file(); return false; });
                    }
                    lidx = 0;
                    break;
                default:
                    lbuf[lidx++] = buf[nc];
                    lbuf[lidx] = 0;
                    if(((string)lbuf).contains("Rebooting"))
                    {
                        changed_state(STATE.reboot);
                        lidx = 0;
                    }
                    break;
            }
        }

        if(rx_mode == 1)
            start_serial_timer();

        return true;
    }

    private void start_serial_timer()
    {
        if(state == STATE.hash)
        {
            iotid = Timeout.add(1000, () => {
                    changed_state(STATE.timeout);
                    iotid = 0;
                    lidx = 0;
                    return false;
                });
        }
    }

    public void start_state()
    {
        Timeout.add(100, () => {
                Posix.write(fd,"#", 1);
                return (state == STATE.none || state == STATE.restart) ? true : false;
            });
    }

    private void setfile (FileStream _dis)
    {
        dis = _dis;
    }

    private void setdump (FileStream _os, string dt)
    {
        os = _os;
        os.printf("# mwptools / naze-cli dump %s\n", dt);
    }

    private void xmit_file()
    {
        bool done = false;
        while(!done)
        {
            string rline;
            rline = dis.read_line ();
            if(rline == null)
            {
                Posix.write(fd,"save\n", 5);
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
                        ; // skip, old version
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

        if(profile < 0 || profile > 2)
            profile = 0;

        if(tprofile < profile)
            tprofile = profile;

        if(tprofile > 2)
            tprofile = 2;

        FileStream mdis = null;
        FileStream mos = null;

        if(args.length > 1)
        {
            var file = File.new_for_path (args[1]);
            if (!file.query_exists ())
            {
                MWPLog.message ("File '%s' doesn't exist.\n", file.get_path ());
                return 255;
            }
            else
            {
                mdis = FileStream.open(args[1], "r");
            }
        }

        var s = new MWSerial();
        var ml = new MainLoop();
        s.rx_mode = -1;
        s.state = STATE.none;

        s.completed.connect(() => {ml.quit();});
        s.changed_state.connect((x) => {
                switch(x)
                {
                    case STATE.hash:
//                    stderr.printf("--- HASH %d\n", profile);
                    s.state = x;
                    s.rx_mode = 1;
                    var str = "profile %d\n".printf(profile);
                    Posix.write(s.fd,str, str.length);
                    Posix.write(s.fd,str, str.length); // deliberate!
                    str = "dump\n";
                    Posix.write(s.fd,str, str.length);
                    break;

                    case STATE.timeout:
                        s.rx_mode = -1;
                        s.state = x;
                        if(mdis == null)
                        {
                            if(profile < tprofile)
                            {
                                profile++;
                                s.rx_mode = 1;
                                s.changed_state(STATE.hash);
                            }
                            else
                            {
                                var str = "exit\r\n";
                                Posix.write(s.fd,str, str.length);
                                Idle.add(() => { ml.quit(); return false;});
                            }
                        }
                        else
                        {
                            s.state = STATE.do_reboot;
                            s.lidx = 0;
                            var str = "defaults\n";
                            Posix.write(s.fd,str, str.length);
                            stdout.printf("#### set defaults ####\n");
                        }
                        break;
                    case STATE.reboot:
                        stdout.printf("#### reboot ####\n");
                        if(s.state != STATE.setconfig)
                        {
                            s.state = STATE.restart;
                            s.start_state();
                        }
                        break;
                    case STATE.setconfig:
                        s.state = x;
                        stdout.printf("#### set conf ####\n");
                        s.setfile(mdis);
                        s.rx_mode = 2;
                        Posix.write(s.fd,"#\n", 2);
                        break;
                    default:
                        break;
                }
            });

        time_t currtime;
        time_t(out currtime);
        string fn;
        string dt;
        dt = Time.local(currtime).format("%FT%H%M%S");
        if(defname == null)
            fn  = "cf_%s.txt".printf(dt);
        else
            fn = defname;

        mos = FileStream.open(fn, "w");
        s.setdump(mos,dt);
        s.start_state();
        ml.run();
        s.close();
        mos = null;
        stdout.puts("Done\n");
        return 0;
    }
}
