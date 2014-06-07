
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

extern int open_serial(string name, uint rate);
extern void close_serial(int fd);
extern int bind_sock(uint16 port);
extern int connect_sock(string host,uint16 port);

public class MWSerial : Object
{
    private int fd=-1;
    private IOChannel io_read;
    private Socket skt;
    private SocketAddress sockaddr;
    private bool is_serial;
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

    private void setup_fd (uint rate)
    {
        if(is_serial == true)
        {
            Posix.termios newtio = {0};
            Posix.speed_t baudrate;

            switch(rate) {
                case 4800:
                    baudrate = Posix.B4800;
                    break;
                case 9600:
                    baudrate = Posix.B9600;
                    break;
                case 19200:
                    baudrate = Posix.B19200;
                    break;
                case 38400:
                    baudrate = Posix.B38400;
                    break;
                case 57600:
                    baudrate = Posix.B57600;
                break;
                case 115200:
                case 0:
                    baudrate = Posix.B115200;
                    break;
                case 230400:
                    baudrate = Posix.B230400;
                    break;
                default:
                    baudrate = Posix.B115200;
                    break;
            }

            Posix.cfsetospeed(ref newtio, baudrate);
            Posix.cfsetispeed(ref newtio, baudrate);

            newtio.c_cflag = (newtio.c_cflag & ~Posix.CSIZE) | Posix.CS8;
            newtio.c_cflag |= Posix.CLOCAL | Posix.CREAD;
            newtio.c_cflag &= ~(Posix.PARENB | Posix.PARODD);
            newtio.c_cflag &= ~Posix.CSTOPB;

            newtio.c_iflag = Posix.IGNBRK;
            newtio.c_lflag = 0;
            newtio.c_oflag = 0;
            newtio.c_cc[Posix.VTIME]=0;
            newtio.c_cc[Posix.VMIN]=0;
            newtio.c_lflag &= ~(Posix.ECHONL|Posix.NOFLSH);

            Posix.tcsetattr(fd, Posix.TCSANOW, newtio);
        }
        available = true;
        setup_reader(fd);
    }

    private void setup_reader(int fd)
    {
        state = States.S_HEADER;
        try {
            io_read = new IOChannel.unix_new(fd);
            if(io_read.set_encoding(null) != IOStatus.NORMAL)
                    error("Failed to set encoding");
            tag = io_read.add_watch(IOCondition.IN | IOCondition.HUP, device_read);
        } catch(IOChannelError e) {
            error("IOChannel: %s", e.message);
        }
    }

    private void setup_udp(string[] parts)
    {
        string host = parts[0];
        var port = (uint16)int.parse(parts[1]);
        try
        {
            if(host.length == 0)
            {
                fd = bind_sock(port);
                skt = new Socket.from_fd(fd);
            }
            else
            {
                fd = connect_sock(host,port);
                skt = new Socket.from_fd(fd);
                sockaddr = skt.get_remote_address();
            }
        } catch(Error e) {
            warning("socket: %s", e.message);
            fd = -1;
        }
    }

    public bool open(string device, uint rate)
    {
        string[] parts;
        parts = device.split (":");
        if(parts.length == 2)
        {
            setup_udp(parts);
            is_serial = false;
        }
        else
        {
            is_serial = true;
            parts = device.split ("@");
            if(parts.length == 2)
            {
                device = parts[0];
                rate = int.parse(parts[1]);
            }
            fd = open_serial(device, rate);
        }
        if(fd < 0) {
            fd = -1;
            warning("Could not open device!\n");
            available = false;
        }
        else
        {
            setup_reader(fd);
            available = true;
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
        close();
    }

    public void close()
    {
        available=false;
        if(fd != -1)
        {
            if(is_serial)
                close_serial(fd);
            else
            {
                try
                {
                    skt.close();
                } catch (Error e)
                {
                    warning ("sock close %s", e.message);
                }
                Posix.close(fd);
                sockaddr=null;
            }
            if(tag > 0)
                Source.remove(tag);
            fd = -1;
        }
    }

    private bool device_read(IOChannel gio, IOCondition cond) {
        uint8 buf[128];
        size_t res;

        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0)
        {
            available = false;
            close();
            serial_lost();
        }
        else
        {
            if(is_serial)
                res = Posix.read(fd,buf,128);
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
            debug("recv: %db\n", (int)res);
            for(var nc = 0; nc < res; nc++)
            {
                switch(state)
                {
                    case States.S_HEADER:
                    case States.S_ERROR:
                        if(state ==  States.S_ERROR)
                        {
                            commerr++;
                            stderr.printf("Comm error count %d\n", commerr);
                        }
                        if (buf[nc] == '$')
                        {
                            state=States.S_HEADER1;
                            errstate = false;
                        }
                        else
                        {
                            debug("fail on header %d %c", buf[nc], buf[nc]);
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
                            debug("fail on header1 %x", buf[nc]);
                            state=States.S_ERROR;
                        }
                        break;

                    case States.S_T_HEADER2:
                        needed = 0;
                        switch(buf[nc])
                        {
                            case 'G':
                                needed = (uint8) sizeof(LTM_GFRAME);
                                cmd = MSP.Cmds.TG_FRAME;
                                break;
                            case 'A':
                                needed = (uint8) sizeof(LTM_AFRAME);
                                cmd = MSP.Cmds.TG_FRAME;
                                break;
                            case 'S':
                                needed = (uint8) sizeof(LTM_SFRAME);
                                cmd = MSP.Cmds.TS_FRAME;
                                break;
                            default:
                                debug("fail on T_header2 %x", buf[nc]);
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
                        if((buf[nc] == readdirn || buf[nc] == '!'))
                        {
                            errstate = (buf[nc] == '!');
                            state = States.S_SIZE;
                        }
                        else
                        {
                            debug("fail on header2 %x", buf[nc]);
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
                        debug("got cmd %d %d", buf[nc], csize);
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
                        debug("data csize = %d needed = %d", csize, needed);
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
                            debug("OK on %d", cmd);
                            state = States.S_HEADER;
                                // FIXME error state
                            serial_event(cmd, raw, csize,errstate);
                            }
                        else
                        {
                            debug("Fail, got %d != %d", buf[nc],checksum);
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
        if(is_serial)
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

    public void send_command(uint8 cmd, void *data, size_t len)
    {
        if(available == true)
        {
            var dsize = (uint8)len;
            uint8 dstr[128];
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

    public void dump(uint8[]buf)
    {
        stderr.printf("dump len = %d\n", buf.length);
        foreach(uint8 b in buf)
        {
            stderr.printf("%02x ", b);
        }
        stderr.printf("\n");
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
