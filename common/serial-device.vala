
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

// valac --pkg posix --pkg gio-2.0 --pkg posix sd-test.vala  serial-device.vala cserial.c

//extern int open_serial(string name, uint rate, uint8 [] eptr, size_t elen);
//extern void close_serial(int fd);

public struct SerialStats
{
    double elapsed;
    ulong rxbytes;
    ulong txbytes;
    double rxrate;
    double txrate;
}

public class MWSerial : Object
{
    private int fd=-1;
    private IOChannel io_read;
    private Socket skt;
    private SocketAddress sockaddr;
    public  States state {private set; get;}
    private uint8 checksum;
    private uint8 csize;
    private uint8 needed;
    private MSP.Cmds cmd;
    private uint8[] raw;
    private int rawp;
    public  bool available {private set; get;}
    private uint tag;
    private char readdirn {set; get; default= '>';}
    private char writedirn {set; get; default= '<';}
    private bool errstate;
    private int commerr;
    private bool rawlog;
    private int raws;
    private Timer timer;
    private Posix.termios oldtio;
    private bool print_raw=false;
    public uint baudrate  {private set; get;}
    private int sp = 0;
    private int64 stime;
    private int64 ltime;
    private SerialStats stats;
    private int commode;

    public enum ComMode
    {
        TTY=1,
        STREAM=2
    }

    public enum Mode
    {
        NORMAL=0,
        SIM = 1
    }

    public enum States
    {
        S_END=0,
            S_HEADER,
            S_HEADER1,
            S_HEADER2,
            S_SIZE,
            S_CMD,
            S_DATA,
            S_CHECKSUM,
            S_ERROR,
            S_T_HEADER2=100,
            }

    public signal void serial_event (MSP.Cmds event, uint8[]result, uint len, bool err);
    public signal void serial_lost ();

    public MWSerial()
    {
        available = false;
    }

    public void clear_counters()
    {
        ltime = stime = 0;
        stats =  {0.0, 0, 0, 0.0, 0.0};
    }

    private void setup_fd (uint rate)
    {
        if((commode & ComMode.TTY) == ComMode.TTY)
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
        }
        available = true;
        setup_reader(fd);
    }

    private void setup_reader(int fd)
    {
        clear_counters();
        state = States.S_HEADER;
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

    private void setup_ip(string host, uint16 port)
    {
        try
        {
            baudrate = 0;
            if(host.length == 0) // Only UDP for mspsim
            {
                try {
                    SocketFamily[] fams = {SocketFamily.IPV6, SocketFamily.IPV4};
                    foreach(var fam in fams)
                    {
                        var sa = new InetSocketAddress (new InetAddress.any(fam),
                                                        (uint16)port);
                        skt = new Socket (fam, SocketType.DATAGRAM, SocketProtocol.UDP);
                        skt.bind (sa, true);
                        break;
                    }
                } catch (Error e) {
                    MWPLog.message ("%s\n",e.message);
                }
            }
            else
            {
                var resolver = Resolver.get_default ();
                var addresses = resolver.lookup_by_name (host, null);
                var address = addresses.nth_data (0);
                sockaddr = new InetSocketAddress (address, port);
                var fam = sockaddr.get_family();
                skt = new Socket (fam, SocketType.DATAGRAM,SocketProtocol.UDP);
                SocketType stype;
                SocketProtocol sproto;
                if((commode & ComMode.STREAM) == ComMode.STREAM)
                {
                    stype = SocketType.STREAM;
                    sproto = SocketProtocol.TCP;
                }
                else
                {
                    stype = SocketType.DATAGRAM;
                    sproto = SocketProtocol.UDP;
                }
                skt = new Socket (fam, stype, sproto);
                skt.connect(sockaddr);
            }
            fd = skt.fd;
        } catch(Error e) {
            warning("socket: %s", e.message);
            fd = -1;
        }
    }

    public bool open(string device, uint rate, out string estr)
    {
        string host = null;
        uint16 port = 0;
        MatchInfo mi;
        Regex regex;
        estr=null;

        print_raw = (Environment.get_variable("MWP_PRINT_RAW") != null);
        try
        {
            regex = new Regex ("^(tcp|udp):\\/\\/(\\S+):(\\d+)");
        } catch(Error e) {
            stderr.printf("err: %s", e.message);
            return false;
        }

        commode = 0;
        if(regex.match(device, 0, out mi))
        {
            if(mi.fetch(1) == "tcp")
                commode = ComMode.STREAM;

            var s =  mi.fetch(2);
            if(s[0] == '[' && s[s.length-1] == ']')
                host = s[1:-1];
            else
                host = s;
            port = (uint16)int.parse(mi.fetch(3));
        }
        else if(device[0] == ':')
        {
            host = "";
            port = (uint16)int.parse(device[1:device.length]);
        }

        if(host != null)
        {
            setup_ip(host, port);
        }
        else
        {
            commode = ComMode.STREAM|ComMode.TTY;
            var parts = device.split ("@");
            if(parts.length == 2)
            {
                device = parts[0];
                rate = int.parse(parts[1]);
            }
            fd = Posix.open(device, Posix.O_RDWR);
            setup_fd((int)rate);
            stderr.puts("Setup Serial\n");
        }

        if(fd < 0)
        {
            var lasterr=Posix.errno;
            var s = Posix.strerror(lasterr);
            estr = "%s (%d)".printf(s,lasterr);
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
        if(rate != -1)
            commode = ComMode.TTY|ComMode.STREAM;
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
                if(print_raw)
                    MWPLog.message("remove tag\n");
                Source.remove(tag);
            }
            if((commode & ComMode.TTY) == ComMode.TTY)
            {
                Posix.tcsetattr (fd, Posix.TCSANOW|Posix.TCSADRAIN, oldtio);
                Posix.close(fd);
            }
            else
            {
                if (!skt.is_closed())
                {
                    try
                    {
                        skt.close();
                    } catch (Error e)
                    {
                        warning ("sock close %s", e.message);
                    }
                }
                sockaddr=null;
            }
            fd = -1;
        }
    }

    public SerialStats dump_stats()
    {
        if(stime == 0)
            stime =  GLib.get_monotonic_time();
        if(ltime == 0 || ltime == stime)
            ltime =  GLib.get_monotonic_time();
        stats.elapsed = (ltime - stime)/1000000.0;
        if (stats.elapsed > 0)
        {
            stats.txrate = stats.txbytes / stats.elapsed;
            stats.rxrate = stats.rxbytes / stats.elapsed;
        }
        return stats;
    }

    private void error_counter()
    {
        commerr++;
        MWPLog.message("Comm error count %d\n", commerr);
        Posix.tcflush(fd, Posix.TCIFLUSH);
    }

    private bool device_read(IOChannel gio, IOCondition cond) {
        uint8 buf[128];
        size_t res;

        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0)
        {
            available = false;
            if(fd != -1)
                serial_lost();
            MWPLog.message("Close on cond %x (fd=%d)\n", cond, fd);
            return false;
        }
        else if (fd != -1)
        {
            if((commode & ComMode.STREAM) == ComMode.STREAM)
            {
                res = Posix.read(fd,buf,128);
                if(res == 0)
                    return true;
            }
            else
            {
                try
                {
                    res = skt.receive_from(out sockaddr, buf);
                } catch(Error e) {
                    debug("recv: %s", e.message);
                    res = 0;
                }
            }

            if(stime == 0)
                stime =  GLib.get_monotonic_time();

            ltime =  GLib.get_monotonic_time();
            stats.rxbytes += res;
            if(print_raw == true)
            {
                dump_raw_data(buf, (int)res);
            }

            for(var nc = 0; nc < res; nc++)
            {
                switch(state)
                {
                    case States.S_ERROR:
                        if (buf[nc] == '$')
                        {
                            sp = nc;
                            state=States.S_HEADER1;
                            errstate = false;
                        }
                        break;

                    case States.S_HEADER:
                        if (buf[nc] == '$')
                        {
                            sp = nc;
                            state=States.S_HEADER1;
                            errstate = false;
                        }
                        else
                        {
                            error_counter();
                            MWPLog.message(" fail on header %x %c\n",
                                          buf[nc], buf[nc]);
                            state=States.S_ERROR;
                        }
                        break;
                    case States.S_HEADER1:
                        if(buf[nc] == 'M')
                        {
                            state=States.S_HEADER2;
                        }
                        else if(buf[nc] == 'T')
                        {
                            state=States.S_T_HEADER2;
                        }
                        else
                        {
                            error_counter();
                            MWPLog.message(" fail on header1 %x\n", buf[nc]);
                            state=States.S_ERROR;
                        }
                        break;

                    case States.S_T_HEADER2:
                        needed = 0;
                        switch(buf[nc])
                        {
                            case 'G':
                                needed = (uint8) MSize.LTM_GFRAME;
                                cmd = MSP.Cmds.TG_FRAME;
                                break;
                            case 'A':
                                needed = (uint8) MSize.LTM_AFRAME;
                                cmd = MSP.Cmds.TA_FRAME;
                                break;
                            case 'S':
                                needed = (uint8) MSize.LTM_SFRAME;
                                cmd = MSP.Cmds.TS_FRAME;
                                break;
                            default:
                                error_counter();
                                MWPLog.message("fail on T_header2 %x\n", buf[nc]);
                                state=States.S_ERROR;
                                break;
                        }
                        if (needed > 0)
                        {
                            csize = needed;
                            raw = new uint8[csize];
                            rawp= 0;
                            checksum = 0;
                            state = States.S_DATA;
                        }
                        break;

                    case States.S_HEADER2:
                        if((buf[nc] == readdirn ||
                            buf[nc] == writedirn ||
                            buf[nc] == '!'))
                        {
                            errstate = (buf[nc] != readdirn); // == '!'
                            state = States.S_SIZE;
                        }
                        else
                        {
                            error_counter();
                            MWPLog.message(" fail on header2 %x\n", buf[nc]);
                            state=States.S_ERROR;
                        }
                        break;

                    case States.S_SIZE:
                        checksum = csize = needed = buf[nc];
                        if(needed > 0)
                        {
                            raw = new uint8[csize];
                            rawp= 0;
                        }
                        state = States.S_CMD;
                        break;
                    case States.S_CMD:
                        debug(" got cmd %d %d", buf[nc], csize);
                        cmd = (MSP.Cmds)buf[nc];
                        checksum ^= cmd;
                        if (csize == 0)
                        {
                            state = States.S_CHECKSUM;
                        }
                        else
                        {
                            state = States.S_DATA;
                        }
                        break;
                    case States.S_DATA:
                            // debug("data csize = %d needed = %d", csize, needed);
                        raw[rawp++] = buf[nc];
                        needed--;
                        if(needed == 0)
                        {
                            checksum = cksum(raw, csize, checksum);
                            state = States.S_CHECKSUM;
                        }
                        break;
                    case States.S_CHECKSUM:
                        if(checksum  == buf[nc])
                        {
                            debug(" OK on %d", cmd);
                            state = States.S_HEADER;
                            if(rawlog == true)
                            {
                                log_raw('i',&buf[sp],nc+1-sp);
                            }
                            serial_event(cmd, raw, csize,errstate);
                            }
                        else
                        {
                            error_counter();
                            MWPLog.message(" CRC Fail, got %d != %d (%d)\n",
                                           buf[nc],checksum,cmd);
                            state = States.S_ERROR;
                        }
                        break;
                    case States.S_END:
                        state = States.S_HEADER;
                        break;
                }
            }
        }
        return true;
    }

    public ssize_t write(void *buf, size_t count)
    {
        ssize_t size;

        if(stime == 0)
            stime =  GLib.get_monotonic_time();

        stats.txbytes += count;

        if((commode & ComMode.STREAM) == ComMode.STREAM)
            size = Posix.write(fd, buf, count);
        else
        {
            try
            {
                uint8 [] sbuf = new uint8[count];
                for(var i =0; i< count; i++)
                {
                    sbuf[i] = *(((uint8*)buf)+i);
                }
                size = skt.send_to (sockaddr, sbuf);
            } catch(Error e) {
                debug("send: %s", e.message);
                size = 0;
            }
        }
        debug("sent %d bytes\n", (int)size);
        if(rawlog == true)
        {
            log_raw('o',buf,(int)count);
        }
        return size;
    }

    public uint8 cksum(uint8[] dstr, size_t len, uint8 init=0)
    {
        var cs = init;
        for(int n = 0; n < len; n++)
        {
            cs ^= dstr[n];
        }
        return cs;
    }

    public void send_ltm(uint8 cmd, void *data, size_t len)
    {
        if(available == true)
        {
            uint8 dstr[128];
            if(len != 0 && data != null)
            {
                dstr[0]='$';
                dstr[1] = 'T';
                dstr[2] = cmd;
                Posix.memcpy(&dstr[3],data,len);
                var ck = cksum(dstr[3:len+3],len,0);
                dstr[3+len] = ck;
                write(dstr, len+4);
            }
        }
    }


    public void send_command(uint8 cmd, void *data, size_t len)
    {
        if(available == true)
        {
            var dsize = (uint8)len;
            uint8 dstr[256];
            dstr[0]='$';
            dstr[1]='M';
            dstr[2]= writedirn;
            dstr[3] = dsize;
            dstr[4] = cmd;
            if (data != null && dsize > 0)
                Posix.memcpy(&dstr[5], data, len);
            len += 3;
            var ck = cksum(dstr[3:len], len, 0);
            dstr[len+2] = ck;
            len += 3;
            write(dstr, len);
        }
    }

    public void send_error(uint8 cmd)
    {
        if(available == true)
        {
            uint8 dstr[8];
            dstr[0]='$';
            dstr[1]='M';
            dstr[2]= '!';
            dstr[3] = 0;
            dstr[4] = cmd;
            dstr[5] = cmd;
            write(dstr, 6);
        }
    }

    private void log_raw(uint8 dirn, void *buf, int len)
    {
        double dt = timer.elapsed ();
        uint8 blen = (uint8)len;
        Posix.write(raws, &dt, sizeof(double));
        Posix.write(raws, &blen, 1);
        Posix.write(raws, &dirn, 1);
        Posix.write(raws, buf,len);
    }

    public void raw_logging(bool state)
    {
        if(state == true)
        {
            time_t currtime;
            time_t(out currtime);
            var fn  = "mwp_%s.raw".printf(Time.local(currtime).format("%F_%H%M%S"));
            raws = Posix.open (fn, Posix.O_TRUNC|Posix.O_CREAT|Posix.O_WRONLY, 0640);
            timer = new Timer ();
            rawlog = true;
        }
        else
        {
            Posix.close(raws);
            timer.stop();
            rawlog = false;
        }
    }


    public void dump_raw_data (uint8[]buf, int len)
    {
        for(var nc = 0; nc < len; nc++)
        {
            if(buf[nc] == '$')
                MWPLog.message("\n");
            stderr.printf("%02x ", buf[nc]);
        }
        stderr.printf("(%d) ",len);
/*
        for(var nc = 0; nc < len; nc++)
        {
            if(buf[nc] > 0x1f && buf[nc] < 0x80)
            {
                stderr.printf("%c", buf[nc]);
            }
            else
            {
                stderr.printf("\\x%02x", buf[nc]);
            }
        }
*/
    }

    public void set_mode(Mode mode)
    {
        if (mode == Mode.NORMAL)
        {
            readdirn='>';
            writedirn= '<';
        }
        else
        {
            readdirn='<';
            writedirn= '>';
        }
    }
}
