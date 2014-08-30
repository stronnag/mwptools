
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
    private DataInputStream dis;
    private static string devname = "/dev/ttyUSB0";
    private static int brate = 115200;
    const OptionEntry[] options = {
        { "device", 'd', 0, OptionArg.STRING, out devname, "device name", "/dev/ttyUSB0"},
        { "baudrate", 'b', 0, OptionArg.INT, out brate, "Baud rate", "115200"},
        {null}
    };

    public MWSerial()
    {
        available = false;
        fd = -1;
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
        for(var nc = 0; nc < res; nc++)
        {
            stdout.putc((char)buf[nc]);
            stdout.flush();
            if(buf[nc] == '#')
            {
                if(dis != null)
                {
                    while(true)
                    {
                        string line;
                        try
                        {
                            line = dis.read_line (null);
                        } catch (Error e) {
                            line = null;
                            stderr.printf("read error %s\n", e.message);
                        }

                        if(line == null)
                        {
                            Posix.write(fd,"exit\n", 5);
                            try { dis.close(); } catch {}
                            dis = null;
                            break;
                        }
                        else if(line[0] == '#' || line.length == 0)
                        {
                            continue;
                        }
                        else
                        {
                            Posix.write(fd, line, line.length);
                            Posix.write(fd,"\n", 1);
                            break;
                        }
                    }
                }
            }
        }
        return true;
    }

    private void setfile (DataInputStream d)
    {
        dis = d;
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

        var file = File.new_for_path (args[1]);

        DataInputStream mdis;

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
                stderr.printf ("Bizaree error %s\n", e.message);
                return 255;
            }
        }

        var s = new MWSerial();
        s.open(devname,brate);
        var ml = new MainLoop();
        Timeout.add(100, () => {
                Posix.write(s.fd,"#", 1);
                return false;
            });

        Timeout.add(100, () => {
                var str = "defaults\n";
                Posix.write(s.fd,str, str.length);
                return false;
            });

        Timeout.add(100, () => {
                var str = "defaults\n";
                Posix.write(s.fd,str, str.length);
                return false;
            });

        Timeout.add(12000, () => {
                s.setfile(mdis);
                Posix.write(s.fd,"#", 1);
                return false;
            });
        ml.run();
        return 0;
    }
}
