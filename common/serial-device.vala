
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
    private uint8 raw[256];
    private int irawp;
    private int drawp;
    public bool available {private set; get;}
    public bool force4 = false;
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
    private uint8 mavcrc;
    private uint8 mavlen;
    private uint8 mavid1;
    private uint8 mavid2;
    private uint16 mavsum;
    private uint16 rxmavsum;

    public enum ComMode
    {
        TTY=1,
        STREAM=2,
        FD=4
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
        S_M_STX = 200,
        S_M_SIZE,
        S_M_SEQ,
        S_M_ID1,
        S_M_ID2,
        S_M_MSGID,
        S_M_DATA,
        S_M_CRC1,
        S_M_CRC2
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
        fd = -1;
        try
        {
            baudrate = 0;
            if((host == null || host.length == 0) &&
               ((commode & ComMode.STREAM) != ComMode.STREAM))
            {
                try {
                    SocketFamily[] fams = {};
                    if(!force4)
                        fams += SocketFamily.IPV6;
                    fams += SocketFamily.IPV4;
                    foreach(var fam in fams)
                    {
                        var sa = new InetSocketAddress (new InetAddress.any(fam),
                                                        (uint16)port);
                        skt = new Socket (fam, SocketType.DATAGRAM, SocketProtocol.UDP);
                        skt.bind (sa, true);
                        fd = skt.fd;
                        break;
                    }
                } catch (Error e) {
                    MWPLog.message ("%s\n",e.message);
                }
            }
            else
            {
                SocketProtocol sproto;
                SocketType stype;
                var resolver = Resolver.get_default ();
                var addresses = resolver.lookup_by_name (host, null);
                foreach (var address in addresses)
                {
                    sockaddr = new InetSocketAddress (address, port);
                    var fam = sockaddr.get_family();

                    if(force4 && fam != SocketFamily.IPV4)
                        continue;

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
                    if(skt != null)
                    {
                        fd = skt.fd;
                        if(fd != -1)
                        {
                            if(stype == SocketType.STREAM)
                            {
                                if (skt.connect(sockaddr))
                                {
                                    Posix.fcntl(fd, Posix.F_SETFL,
                                                Posix.fcntl(fd, Posix.F_GETFL, 0) |
                                                Posix.O_NONBLOCK);
                                    break;
                                }
                                else
                                {
                                    skt.close();
                                    fd = -1;
                                }
                            }
                            else
                                break;
                        }
                    }
                }
            }
        } catch(Error e) {
            MWPLog.message("socket: %s", e.message);
            fd = -1;
        }
    }

    public bool open(string device, uint rate, out string estr)
    {
        string host = null;
        uint16 port = 0;
        MatchInfo mi;
        Regex regex;
        string []parts;

        estr=null;

        print_raw = (Environment.get_variable("MWP_PRINT_RAW") != null);
        try
        {
            regex = new Regex ("^(tcp|udp):\\/\\/(\\S*):(\\d+)");
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
            parts = device.split ("@");
            if(parts.length == 2)
            {
                device  = parts[0];
                rate = int.parse(parts[1]);
            }
            fd = Posix.open(device, Posix.O_RDWR);
            setup_fd((int)rate);
        }

        if(fd < 0)
        {
            var lasterr=Posix.errno;
            var s = Posix.strerror(lasterr);
            estr = "%s (%d)".printf(s,lasterr);
            MWPLog.message(estr);
            fd = -1;
            available = false;
        }
        else
        {
            MWPLog.message("Connected %s\n", device);
            available = true;
            setup_reader(fd);
        }
        return available;
    }

    public bool open_fd(int _fd, int rate, bool rawfd = false)
    {
        fd = _fd;
        if(rate != -1)
            commode = ComMode.TTY|ComMode.STREAM;
        if(rawfd)
            commode = ComMode.FD|ComMode.STREAM;
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
            else if ((commode & ComMode.FD) == ComMode.FD)
                Posix.close(fd);
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
        size_t res = 0;

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
#if HAVE_FIONREAD
                int avb=0;
                int ires;
                ires = Posix.ioctl(fd,Linux.Termios.FIONREAD,&avb);
                if(ires == 0 && avb > 0)
                {
                    if(avb > 128)
                        avb = 128;
                    res = Posix.read(fd,buf,avb);
                    if(res == 0)
                        return true;
                }
                else
                    return true;
#else
                res = Posix.read(fd,buf,128);
                if(res == 0)
                    return true;
#endif
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
                if (irawp == 255)
                {
                    state = States.S_ERROR;
                }

                switch(state)
                {
                    case States.S_ERROR:
                        irawp = 0;
                        if (buf[nc] == '$')
                        {
                            sp = nc;
                            state=States.S_HEADER1;
                            errstate = false;
                        }
                        else if (buf[nc] == 0xfe)
                        {
                            sp = nc;
                            state=States.S_M_SIZE;
                            errstate = false;
                        }
                        break;

                    case States.S_HEADER:
                        irawp = 0;
                        raw[irawp++] = buf[nc];
                        if (buf[nc] == '$')
                        {
                            sp = nc;
                            state=States.S_HEADER1;
                            errstate = false;
                        }
                        else if (buf[nc] == 0xfe)
                        {
                            sp = nc;
                            state=States.S_M_SIZE;
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
                        raw[irawp++] = buf[nc];
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
                        raw[irawp++] = buf[nc];
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
                            case 'O':
                                needed = (uint8) MSize.LTM_OFRAME;
                                cmd = MSP.Cmds.TO_FRAME;
                                break;
                            case 'N':
                                needed = (uint8) MSize.LTM_NFRAME;
                                cmd = MSP.Cmds.TN_FRAME;
                                break;
                            case 'Q':
                                needed = 1;
                                cmd = MSP.Cmds.TQ_FRAME;
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
                            drawp= irawp;
                            checksum = 0;
                            state = States.S_DATA;
                        }
                        break;

                    case States.S_HEADER2:
                        raw[irawp++] = buf[nc];
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
                        raw[irawp++] = buf[nc];
                        checksum = csize = needed = buf[nc];
                        state = States.S_CMD;
                        break;
                    case States.S_CMD:
                        raw[irawp++] = buf[nc];
                        drawp= irawp;
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
                        raw[irawp++] = buf[nc];
                        needed--;
                        if(needed == 0)
                        {
                            checksum = cksum(raw[drawp:drawp+csize],
                                             csize, checksum);
                            state = States.S_CHECKSUM;
                        }
                        break;
                    case States.S_CHECKSUM:
                        if(checksum  == buf[nc])
                        {
                            raw[irawp++] = buf[nc];
                            debug(" OK on %d", cmd);
                            state = States.S_HEADER;
                            if(rawlog == true)
                            {
                                log_raw('i', raw, irawp);
                            }
                            serial_event(cmd, raw[drawp:drawp+csize],
                                         csize,errstate);
                            irawp = drawp = 0;
                        }
                        else
                        {
                            error_counter();
                            MWPLog.message(" CRC Fail, got %d != %d (cmd=%d)\n",
                                           buf[nc],checksum,cmd);
                            state = States.S_ERROR;
                        }
                        break;
                    case States.S_END:
                        state = States.S_HEADER;
                        break;
                    case States.S_M_SIZE:
                        csize = needed = buf[nc];
                        mavsum = mavlink_crc(0xffff, csize);
                        if(needed > 0)
                        {
                            irawp= 0;
                        }
                        state = States.S_M_SEQ;
                        break;
                    case States.S_M_SEQ:
                        mavsum = mavlink_crc(mavsum, buf[nc]);
                        state = States.S_M_ID1;
                        break;
                    case States.S_M_ID1:
                        mavid1 = buf[nc];
                        mavsum = mavlink_crc(mavsum, mavid1);
                        state = States.S_M_ID2;
                        break;
                    case States.S_M_ID2:
                        mavid2 = buf[nc];
                        mavsum = mavlink_crc(mavsum, mavid2);
                        state = States.S_M_MSGID;
                        break;
                    case States.S_M_MSGID:
                        cmd = (MSP.Cmds)buf[nc];
                        mavsum = mavlink_crc(mavsum, cmd);
                        if (csize == 0)
                            state = States.S_M_CRC1;
                        else
                            state = States.S_M_DATA;
                        break;
                    case States.S_M_DATA:
                        mavsum = mavlink_crc(mavsum, buf[nc]);
                        raw[irawp++] = buf[nc];
                        needed--;
                        if(needed == 0)
                        {
                            state = States.S_M_CRC1;
                            mavlink_meta(cmd);
                            mavsum = mavlink_crc(mavsum, mavcrc);
                        }
                        break;
                    case States.S_M_CRC1:
                        rxmavsum = buf[nc];
                        state = States.S_M_CRC2;
                        break;
                    case States.S_M_CRC2:
                        rxmavsum |= (buf[nc] << 8);
                        if(rxmavsum == mavsum)
                        {
//                            MWPLog.message(" MAVMSG cmd=%u, len=%u res = %u\n",
//                                           cmd,csize, cmd+MSP.Cmds.MAVLINK_MSG_ID_HEARTBEAT);
                            serial_event(cmd+MSP.Cmds.MAVLINK_MSG_ID_HEARTBEAT,
                                         raw, csize,errstate);
                            state = States.S_HEADER;
                        }
                        else
                        {
                            error_counter();
                            MWPLog.message(" MAVCRC Fail, got %x != %x [%x %x] (cmd=%u, len=%u)\n",
                                           rxmavsum, mavsum,
                                           mavid1, mavid2,
                                           cmd, csize);
                            state = States.S_ERROR;
                        }
                        break;
                }
            }
        }
        return true;
    }

    private void mavlink_meta(uint8 id)
    {
        switch(id)
        {
            case 0:
                mavcrc = 50;
                mavlen = 9;
                break;
            case 1:
                mavcrc = 124;
                mavlen = 31;
                break;
            case 24:
                mavcrc = 24;
                mavlen = 30;
                break;
            case 30:
                mavcrc = 39;
                mavlen = 28;
                break;
            case 35:
                mavcrc = 244;
                mavlen = 22;
                break;
            case 49:
                mavcrc = 39;
                mavlen = 12;
                break;
            case 74:
                mavcrc = 20;
                mavlen = 20;
                break;
            case 166:
                mavcrc = 21;
                mavlen = 9;
                break;
            case 109:
                mavcrc = 185;
                mavlen = 9;
                break;

            default:
                mavcrc = 255;
                mavlen = 255;
                break;
        }
    }

    public uint16 mavlink_crc(uint16 acc, uint8 val)
    {
        uint8 tmp;
        tmp = val ^ (uint8)(acc&0xff);
        tmp ^= (tmp<<4);
        acc = (acc>>8) ^ (tmp<<8) ^ (tmp<<3) ^ (tmp>>4);
        return acc;
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
            unowned uint8[] sbuf = (uint8[]) buf;
            sbuf.length = (int)count;
            try
            {
                size = skt.send_to (sockaddr, sbuf);
            } catch(Error e) {
                stderr.printf("err::send: %s", e.message);
                size = 0;
            }
        }
        debug("sent %d %d bytes\n", (int)size, (int)count);
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
