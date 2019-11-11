/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
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


public struct SerialStats
{
    double elapsed;
    ulong rxbytes;
    ulong txbytes;
    double rxrate;
    double txrate;
    ulong  msgs;
}

public class SportDev : Object
{
    public enum FrID {
        ALT_ID = 0x0100,
        VARIO_ID = 0x0110,
        CURR_ID = 0x0200,
        VFAS_ID = 0x0210,
        CELLS_ID = 0x0300,
        T1_ID = 0x0400,
        T2_ID = 0x0410,
        RPM_ID = 0x0500,
        FUEL_ID = 0x0600,
        ACCX_ID = 0x0700,
        ACCY_ID = 0x0710,
        ACCZ_ID = 0x0720,
        GPS_LONG_LATI_ID = 0x0800,
        GPS_ALT_ID = 0x0820,
        GPS_SPEED_ID = 0x0830,
        GPS_COURS_ID = 0x0840,
        GPS_TIME_DATE_ID = 0x0850,
        A3_ID = 0x0900,
        A4_ID = 0x0910,
        AIR_SPEED_ID = 0x0a00,
        RBOX_BATT1_ID = 0x0b00,
        RBOX_BATT2_ID = 0x0b10,
        RBOX_STATE_ID = 0x0b20,
        RBOX_CNSP_ID = 0x0b30,
        DIY_ID = 0x5000,
        DIY_STREAM_ID = 0x5000,
        RSSI_ID = 0xf101,
        ADC1_ID = 0xf102,
        ADC2_ID = 0xf103,
        SP2UART_A_ID = 0xfd00,
        SP2UART_B_ID = 0xfd01,
        BATT_ID = 0xf104,
        SWR_ID = 0xf105,
        XJT_VERSION_ID = 0xf106,
        FUEL_QTY_ID = 0x0a10,
        PITCH      = 0x0430 ,
        ROLL       = 0x0440 ,
        HOME_DIST  = 0x0420
    }

    private enum FrProto {
        P_START = 0x7e,
        P_STUFF = 0x7d,
        P_MASK  = 0x20,
        P_SIZE = 10
    }

    private uint8 buf[64];
    private bool stuffed = false;
    private uint8 nb = 0;
    private uint good = 0;
    private uint bad = 0;
    private uint nshort = 0;


    private bool fr_checksum(uint8[] buf)
    {
        uint16 crc = 0;
        for(var i = 2; i < 10; i++)
        {
            crc += buf[i];
            crc += crc >> 8;
            crc &= 0xff;
        }
        return (crc == 0xff);
    }

    private uint8 * deserialise_u32(uint8* rp, out uint32 v)
    {
        v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
        return rp + sizeof(uint32);
    }

    private uint8 * deserialise_u16(uint8* rp, out uint16 v)
    {
        v = *rp | (*(rp+1) << 8);
        return rp + sizeof(uint16);
    }

    public delegate void DelegateType (uint32 a,uint32 b);

    public void  extract_messages(DelegateType d, uint8* raw, size_t len)
    {
        for(var i = 0; i < len; i++)
        {
            uint8 b = *raw++;
            if (b == FrProto.P_START)
            {
                if (nb == FrProto.P_SIZE)
                {
                    bool res = fr_checksum(buf);
                    if(res)
                    {
                        ushort id;
                        uint val;
                        deserialise_u16(&buf[3], out id);
                        deserialise_u32(&buf[5], out val);
                        d((uint32)id,val);
                        good++;
                    }
                    else
                        bad++;
                }
                else
                    nshort++;

                nb = 0;
            }
            if (stuffed)
            {
                b = b ^ FrProto.P_MASK;
                stuffed = false;
            }
            else if (b == FrProto.P_STUFF)
            {
                stuffed = true;
                continue;
            }
            buf[nb] = b;
            nb++;
            if (nb > FrProto.P_SIZE)
            {
                nb = 0;
                bad++;
            }
        }
    }
}

public class MWSerial : Object
{
    private string devname;
    private int fd=-1;
    private IOChannel io_read;
    private Socket skt;
    private SocketAddress sockaddr;
    public  States state {private set; get;}
    private uint8 xflags;
    private uint8 checksum;
    private uint8 checksum2;
    private uint16 csize;
    private uint16 needed;
    private uint16 xcmd;
    private MSP.Cmds cmd;
    private int irxbufp;
    private uint16 rxbuf_alloc;
    private uint16 txbuf_alloc = 256;
    private uint8 []rxbuf;
    private uint8 []txbuf;
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
    private bool print_raw=false;
    public uint baudrate  {private set; get;}
    private int sp = 0;
    private int64 stime;
    private int64 ltime;
    private SerialStats stats;
    private int commode;
    private uint16 mavsum;
    private uint16 rxmavsum;
    private bool encap = false;
    public bool use_v2 = false;
    public ProtoMode pmode  {set; get; default=ProtoMode.NORMAL;}
    private bool fwd = false;
    private bool ro = false;
    private uint8 mavseqno = 0;
    private uint8[] devbuf;
    private bool sport = false;
    private SportDev spdev;

    const uint8[] MAVCRCS = {
         50,124,137,  0,237,217,104,119,  0,  0,  0, 89,  0,  0,  0,  0,
          0,  0,  0,  0,214,159,220,168, 24, 23,170,144, 67,115, 39,246,
        185,104,237,244,222,212,  9,254,230, 28, 28,132,221,232, 11,153,
         41, 39,  0,  0,  0,  0, 15,  3,  0,  0,  0,  0,  0,153,183, 51,
         82,118,148, 21,  0,243,124,  0,  0, 38, 20,158,152,143,  0,  0,
          0,106, 49, 22,143,140,  5,150,  0,231,183, 63, 54,  0,  0,  0,
          0,  0,  0,  0,175,102,158,208, 56, 93,138,108, 32,185, 84, 34,
          0,124,237,  4, 76,128, 56,116,134,237,203,250, 87,203,220, 25,
        226,  0, 29,223, 85,  6,229,203,  1,  0,  0,  0,  0,  0,  0,  0,
          0,  0,  0,154, 49,  0,  0,108, 86, 95,224,  0,  0,  0,  0,  0,
         22,  0,  0,  0,  0,  0,  0,  0,  0,  0, 28,249,182,  0,  0,  0,
          0,  0,  0,  0,153, 16, 29,162,  0,  0,  0,  0,  0,  0, 90, 95,
         36,  0,  0, 88,  0,  0,  0,  0,254,  0,  0,  0,  0, 87, 19,  0,
          0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
          0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
          0,  0,  0,  0,  0,  0,  0,  0,  8,204, 49,170, 44, 83, 46,  0
    };

    public enum MemAlloc
    {
        RX=1024,
        TX=256,
        DEV=2048
    }

    public enum ComMode
    {
        TTY=1,
        STREAM=2,
        FD=4,
        BT=8
    }

    public enum Mode
    {
        NORMAL=0,
        SIM = 1
    }

    public enum ProtoMode
    {
        NORMAL,
        CLI,
        FRSKY
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
        S_JUMBO1,
        S_JUMBO2,
        S_T_HEADER2=100,
        S_X_HEADER2=200,
        S_X_FLAGS,
        S_X_ID1,
        S_X_ID2,
        S_X_LEN1,
        S_X_LEN2,
        S_X_DATA,
        S_X_CHECKSUM,
        S_M_STX = 300,
        S_M_SIZE,
        S_M_SEQ,
        S_M_ID1,
        S_M_ID2,
        S_M_MSGID,
        S_M_DATA,
        S_M_CRC1,
        S_M_CRC2
    }

    public signal void serial_event (MSP.Cmds event, uint8[]result, uint len, uint8 flags, bool err);
    public signal void cli_event(uint8[]raw, uint len);
    public signal void serial_lost ();
    public signal void sport_event(uint32 a, uint32 b);

    public MWSerial.forwarder()
    {
        fwd = true;
        available = sport = false;
        set_txbuf(MemAlloc.TX);
    }

    public MWSerial.reader()
    {
        available = sport = fwd = false;
        ro = true;
        rxbuf_alloc = MemAlloc.RX;
        rxbuf = new uint8[rxbuf_alloc];
        devbuf = new uint8[MemAlloc.DEV];
    }

    public MWSerial.smartport()
    {
        sport  = true;
        fwd = available = false;
        rxbuf_alloc = MemAlloc.RX;
        rxbuf = new uint8[rxbuf_alloc];
        devbuf = new uint8[MemAlloc.DEV];
    }

    public void sport_handler(uint32 a, uint32 b)
    {
        sport_event(a, b);
    }

    public MWSerial()
    {
        sport = fwd =  available = false;
        rxbuf_alloc = MemAlloc.RX;
        rxbuf = new uint8[rxbuf_alloc];
        txbuf = new uint8[txbuf_alloc];
        devbuf = new uint8[MemAlloc.DEV];
    }

    public int get_fd()
    {
        return fd;
    }

    public void set_txbuf(uint16 sz)
    {
        txbuf = new uint8[sz];
        txbuf_alloc = sz;
    }

    public uint16 get_txbuf()
    {
        return txbuf_alloc;
    }

    public uint16 get_rxbuf()
    {
        return rxbuf_alloc;
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
            MwpSerial.set_speed(fd, (int)rate);
        }
        available = true;
        setup_reader();
    }

    public void setup_reader()
    {
        clear_counters();
        state = States.S_HEADER;
        if(sport == true)
            spdev = new SportDev();

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

    private void setup_ip(string host, uint16 port, string? rhost=null, uint16 rport = 0)
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
//                        print("bind %s %d %d\n", fam.to_string(), fd, port);
                        break;
                    }
                    if(rhost != null && rport != 0)
                    {
                        var resolver = Resolver.get_default ();
                        var addresses = resolver.lookup_by_name (rhost, null);
                        var addr0 = addresses.nth_data (0);
                        sockaddr = new InetSocketAddress(addr0,rport);
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
                            if (skt.connect(sockaddr))
                            {
                                set_noblock();
                            }
                            else
                            {
                                skt.close();
                                fd = -1;
                            }
                        }
                        break;
                    }
                }
            }
        } catch(Error e) {
            MWPLog.message("socket: %s\n", e.message);
            fd = -1;
        }
    }

    private void set_noblock()
    {
        Posix.fcntl(fd, Posix.F_SETFL,
                    Posix.fcntl(fd, Posix.F_GETFL, 0) |
                    Posix.O_NONBLOCK);
    }


    public bool open_sport(string device, out string estr)
    {
        sport  = true;
        fwd = false;
        MWPLog.message("SPORT: open %s\n", device);
        return open(device, 0, out estr);
    }


    public bool open(string device, uint rate, out string estr)
    {
        if(open_w(device, rate, out estr))
        {
            if(fwd == false)
                setup_reader();
            else
                set_noblock();
        }
        return available;
    }

    public bool open_w(string _device, uint rate, out string estr)
    {
        string host = null;
        uint16 port = 0;
        Regex regex;
        string []parts;
        int lasterr = 0;
        string device;
        int n;

        if((n = _device.index_of_char(' ')) == -1)
            device = _device;
        else
            device = _device.substring(0,n);

        devname = device;

        estr=null;

        print_raw = (Environment.get_variable("MWP_PRINT_RAW") != null);
        try
        {
            regex = new Regex("^(tcp|udp):\\/\\/([\\[\\]:A-Za-z\\-\\.0-9]*):(\\d+)\\/{0,1}([A\\-Za-z\\-\\.0-9]*):{0,1}(\\d*)");
        } catch(Error e) {
            stderr.printf("err: %s", e.message);
            return false;
        }

        commode = 0;

        if(device.length == 17 &&
           device[2] == ':' && device[5] == ':')
        {
            fd = BTSocket.connect(device, &lasterr);
            if (fd != -1)
            {
                commode = ComMode.FD|ComMode.STREAM|ComMode.BT;
                set_noblock();
            }
        }
        else
        {
            string remhost = null;
            uint16 remport = 0;
            parts = regex.split(device);
            if (parts.length == 7)
            {
                if(parts[1] == "tcp")
                    commode = ComMode.STREAM;

                var s =  parts[2];
                if(s[0] == '[' && s[s.length-1] == ']')
                    host = s[1:-1];
                else
                    host = s;
                port = (uint16)int.parse(parts[3]);
                if(parts[4] != "")
                {
                    remhost = parts[4];
                    remport = (uint16)int.parse(parts[5]);
                }
            }
            else if(device[0] == ':')
            {
                host = "";
                port = (uint16)int.parse(device[1:device.length]);
            }

            if(host != null)
            {
                setup_ip(host, port, remhost, remport);
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
                fd = MwpSerial.open(device, (int)rate);
            }
            lasterr=Posix.errno;
        }

        if(fd < 0)
        {
            uint8 [] sbuf = new uint8[1024];
            var s = MwpSerial.error_text(lasterr, sbuf, 1024);
            estr = "%s %s (%d)".printf(device, s,lasterr);
            MWPLog.message("%s\n", estr);
            fd = -1;
            available = false;
        }
        else
        {
            available = true;
        }
        return available;
    }


    public bool open_fd(int _fd, int rate, bool rawfd = false)
    {
        devname = "fd #%d".printf(_fd);
        fd = _fd;
        sport = fwd =  false;
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
                tag = 0;
            }
            if((commode & ComMode.TTY) == ComMode.TTY)
            {
                MwpSerial.close(fd);
                fd = -1;
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
        MWPLog.message("Comm error count %d\r\n", commerr);
        MwpSerial.flush(fd);
    }

    private void check_rxbuf_size()
    {
        if (csize > rxbuf_alloc)
        {
            while (csize > rxbuf_alloc)
                rxbuf_alloc += MemAlloc.RX;
            rxbuf = new uint8[rxbuf_alloc];
        }
    }

    private void check_txbuf_size(size_t sz)
    {
        if (sz > txbuf_alloc)
        {
            while (sz > txbuf_alloc)
                txbuf_alloc += MemAlloc.TX;
            txbuf = new uint8[txbuf_alloc];
        }
    }

    private void process_sport(uint8[]raw, size_t len)
    {
        spdev.extract_messages(sport_handler, raw, len);
    }

    private void show_cond(IOCondition cond)
    {
        StringBuilder sb = new StringBuilder("");
        sb.append_printf("Close %s : ", devname);
#if LSRVAL
        // no to_string for conditions
#else
        sb.append_c(' ');
        for(var j = 0; j < 8; j++)
        {
            IOCondition n = (IOCondition)(1 << j);
            if((cond & n) == n)
            {
                sb.append(n.to_string());
                sb.append_c('|');
            }
        }
        sb.truncate(sb.len-1);
#endif
        sb.append_printf(" (%x)\n", cond);
        MWPLog.message(sb.str);
    }

    private bool device_read(IOChannel gio, IOCondition cond)
    {
        ssize_t res = 0;

        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0)
        {
            show_cond(cond);
            available = false;
            if(fd != -1)
                serial_lost();
            tag = 0; // REMOVE will remove the iochannel watch
            return Source.REMOVE;
        }
        else if (fd != -1 && (cond & IOCondition.IN) != 0)
        {
            if((commode & ComMode.BT) == ComMode.BT)
            {
                res = Posix.recv(fd,devbuf,MemAlloc.DEV,0);
                if(res == 0)
                    return Source.CONTINUE;
            }
            else if((commode & ComMode.STREAM) == ComMode.STREAM)
            {
                res = Posix.read(fd,devbuf,MemAlloc.DEV);
                if(res == 0)
                {
                    if((commode & ComMode.TTY) != ComMode.TTY)
                        serial_lost();
                    return Source.CONTINUE;
                }
            }
            else
            {
                try
                {
                    res = skt.receive_from(out sockaddr, devbuf);
                } catch(Error e) {
                    debug("recv: %s", e.message);
                    res = 0;
                }
            }

            if(sport == true)
            {
                if(res > 0)
                {
                    process_sport(devbuf, res);
                    if(rawlog == true)
                        log_raw('s',devbuf,(int)res);
                }
            }
            else if(pmode == ProtoMode.CLI)
            {
                csize = (uint16)res;
                cli_event(devbuf, csize);
            }
            else
            {
                if(stime == 0)
                    stime =  GLib.get_monotonic_time();

                ltime =  GLib.get_monotonic_time();
                stats.rxbytes += res;
                if(print_raw == true)
                {
                    dump_raw_data(devbuf, (int)res);
                }
                if(rawlog == true)
                {
                    log_raw('i', devbuf, (int)res);
                }

                for(var nc = 0; nc < res; nc++)
                {
                    switch(state)
                    {
                        case States.S_ERROR:
                            if (devbuf[nc] == '$')
                            {
                                sp = nc;
                                state=States.S_HEADER1;
                                errstate = false;
                            }
                            else if (devbuf[nc] == 0xfe)
                            {
                                sp = nc;
                                state=States.S_M_SIZE;
                                errstate = false;
                            }
                            break;

                        case States.S_HEADER:
                            if (devbuf[nc] == '$')
                            {
                                sp = nc;
                                state=States.S_HEADER1;
                                errstate = false;
                            }
                            else if (devbuf[nc] == 0xfe)
                            {
                                sp = nc;
                                state=States.S_M_SIZE;
                                errstate = false;
                            }
                            else
                            {
                                error_counter();
                                MWPLog.message("expected header0 (%x)\n", devbuf[nc]);
                                state=States.S_ERROR;
                            }

                            break;
                        case States.S_HEADER1:
                            encap = false;
                            irxbufp=0;
                            if(devbuf[nc] == 'M')
                            {
                                state=States.S_HEADER2;
                            }
                            else if(devbuf[nc] == 'T')
                            {
                                state=States.S_T_HEADER2;
                            }
                            else if(devbuf[nc] == 'X')
                            {
                                state=States.S_X_HEADER2;
                            }
                            else
                            {
                                error_counter();
                                MWPLog.message("fail on header1 %x\n", devbuf[nc]);
                                state=States.S_ERROR;
                            }
                            break;

                        case States.S_T_HEADER2:
                            needed = 0;
                            switch(devbuf[nc])
                            {
                                case 'G':
                                    needed = (uint16) MSize.LTM_GFRAME;
                                    cmd = MSP.Cmds.TG_FRAME;
                                    break;
                                case 'A':
                                    needed = (uint16) MSize.LTM_AFRAME;
                                    cmd = MSP.Cmds.TA_FRAME;
                                    break;
                                case 'S':
                                    needed = (uint16) MSize.LTM_SFRAME;
                                    cmd = MSP.Cmds.TS_FRAME;
                                    break;
                                case 'O':
                                    needed = (uint16) MSize.LTM_OFRAME;
                                    cmd = MSP.Cmds.TO_FRAME;
                                    break;
                                case 'N':
                                    needed = (uint16) MSize.LTM_NFRAME;
                                    cmd = MSP.Cmds.TN_FRAME;
                                    break;
                                case 'X':
                                    needed = (uint16) MSize.LTM_XFRAME;
                                    cmd = MSP.Cmds.TX_FRAME;
                                    break;
                                        // Lower case are 'private'
                                case 'q':
                                    needed = 2;
                                    cmd = MSP.Cmds.Tq_FRAME;
                                    break;
                                case 'a':
                                    needed = 2;
                                    cmd = MSP.Cmds.Ta_FRAME;
                                    break;
                                case 'x':
                                    needed = 1;
                                    cmd = MSP.Cmds.Tx_FRAME;
                                    break;
                                default:
                                    error_counter();
                                    MWPLog.message("fail on T_header2 %x\n", devbuf[nc]);
                                    state=States.S_ERROR;
                                    break;
                            }
                            if (needed > 0)
                            {
                                csize = needed;
                                irxbufp = 0;
                                checksum = 0;
                                state = States.S_DATA;
                            }
                            break;

                        case States.S_HEADER2:
                            if((devbuf[nc] == readdirn ||
                                devbuf[nc] == writedirn ||
                                devbuf[nc] == '!'))
                            {
                                errstate = (devbuf[nc] != readdirn); // == '!'
                                state = States.S_SIZE;
                            }
                            else
                            {
                                error_counter();
                                MWPLog.message("fail on header2 %x\n", devbuf[nc]);
                                state=States.S_ERROR;
                            }
                            break;

                        case States.S_SIZE:
                            csize = devbuf[nc];
                            checksum = devbuf[nc];
                            state = States.S_CMD;
                            break;
                        case States.S_CMD:
                            debug(" got cmd %d %d", devbuf[nc], csize);
                            cmd = (MSP.Cmds)devbuf[nc];
                            checksum ^= cmd;
                            if(cmd == MSP.Cmds.MSPV2)
                            {
                                encap = true;
                                state = States.S_X_FLAGS;
                            }
                            else if (csize == 255)
                            {
                                state = States.S_JUMBO1;
                            }
                            else
                            {
                                if (csize == 0)
                                {
                                    state = States.S_CHECKSUM;
                                }
                                else
                                {
                                    state = States.S_DATA;
                                    irxbufp = 0;
                                    needed = csize;
                                    check_rxbuf_size();
                                }
                            }
                            break;

                        case States.S_JUMBO1:
                            checksum ^= devbuf[nc];
                            csize = devbuf[nc];
                            state = States.S_JUMBO2;
                            break;

                        case States.S_JUMBO2:
                            checksum ^= devbuf[nc];
                            csize |= (uint16)devbuf[nc] << 8;
                            needed = csize;
                            irxbufp = 0;
                            if (csize == 0)
                                state = States.S_CHECKSUM;
                            else
                            {
                                state = States.S_DATA;
                                check_rxbuf_size();
                            }
                            break;

                        case States.S_DATA:
                            rxbuf[irxbufp++] = devbuf[nc];
                            checksum ^= devbuf[nc];
                            needed--;
                            if(needed == 0)
                                state = States.S_CHECKSUM;
                            break;
                        case States.S_CHECKSUM:
                            if(checksum  == devbuf[nc])
                            {
                                debug(" OK on %d", cmd);
                                state = States.S_HEADER;
                                stats.msgs++;
                                if(cmd < MSP.Cmds.MSPV2 || cmd > MSP.Cmds.LTM_BASE)
                                    serial_event(cmd, rxbuf, csize, 0, errstate);
                                irxbufp = 0;
                            }
                            else
                            {
                                error_counter();
                                MWPLog.message("CRC Fail, got %d != %d (cmd=%d)\n",
                                               devbuf[nc],checksum,cmd);
                                state = States.S_ERROR;
                            }
                            break;
                        case States.S_END:
                            state = States.S_HEADER;
                            break;

                        case States.S_X_HEADER2:
                            if((devbuf[nc] == readdirn ||
                                devbuf[nc] == writedirn ||
                                devbuf[nc] == '!'))
                            {
                                errstate = (devbuf[nc] != readdirn); // == '!'
                                state = States.S_X_FLAGS;
                            }
                            else
                            {
                                error_counter();
                                MWPLog.message("fail on header2 %x\n", devbuf[nc]);
                                state=States.S_ERROR;
                            }
                            break;

                        case States.S_X_FLAGS:
                            checksum ^= devbuf[nc];
                            checksum2 = crc8_dvb_s2(0, devbuf[nc]);
                            xflags = devbuf[nc];
                            state = States.S_X_ID1;
                            break;
                        case States.S_X_ID1:
                            checksum ^= devbuf[nc];
                            checksum2 = crc8_dvb_s2(checksum2, devbuf[nc]);
                            xcmd = devbuf[nc];
                            state = States.S_X_ID2;
                            break;
                        case States.S_X_ID2:
                            checksum ^= devbuf[nc];
                            checksum2 = crc8_dvb_s2(checksum2, devbuf[nc]);
                            xcmd |= (uint16)devbuf[nc] << 8;
                            state = States.S_X_LEN1;
                            break;
                        case States.S_X_LEN1:
                            checksum ^= devbuf[nc];
                            checksum2 = crc8_dvb_s2(checksum2, devbuf[nc]);
                            csize = devbuf[nc];
                            state = States.S_X_LEN2;
                            break;
                        case States.S_X_LEN2:
                            checksum ^= devbuf[nc];
                            checksum2 = crc8_dvb_s2(checksum2, devbuf[nc]);
                            csize |= (uint16)devbuf[nc] << 8;
                            needed = csize;
                            if(needed > 0)
                            {
                                check_rxbuf_size();
                                state = States.S_X_DATA;
                            }
                            else
                                state = States.S_X_CHECKSUM;
                            break;
                        case States.S_X_DATA:
                            checksum ^= devbuf[nc];
                            checksum2 = crc8_dvb_s2(checksum2, devbuf[nc]);
                            rxbuf[irxbufp++] = devbuf[nc];
                            needed--;
                            if(needed == 0)
                                state = States.S_X_CHECKSUM;
                            break;
                        case States.S_X_CHECKSUM:
                            checksum ^= devbuf[nc];
                            if(checksum2  == devbuf[nc])
                            {
                                debug(" OK on %d", cmd);

                                state = (encap) ? States.S_CHECKSUM : States.S_HEADER;
                                stats.msgs++;
                                serial_event((MSP.Cmds)xcmd, rxbuf, csize,
                                             xflags, errstate);
                                irxbufp = 0;
                            }
                            else
                            {
                                error_counter();
                                MWPLog.message("X-CRC Fail, got %d != %d (cmd=%d)\n",
                                               devbuf[nc],checksum,cmd);
                                state = States.S_ERROR;
                            }
                            break;

                        case States.S_M_SIZE:
                            csize = needed = devbuf[nc];
                            mavsum = mavlink_crc(0xffff, (uint8)csize);
                            if(needed > 0)
                            {
                                irxbufp= 0;
                                check_rxbuf_size();
                            }
                            state = States.S_M_SEQ;
                            break;
                        case States.S_M_SEQ:
                            mavsum = mavlink_crc(mavsum, devbuf[nc]);
                            state = States.S_M_ID1;
                            break;
                        case States.S_M_ID1:
                            mavsum = mavlink_crc(mavsum, devbuf[nc]);
                            state = States.S_M_ID2;
                            break;
                        case States.S_M_ID2:
                            mavsum = mavlink_crc(mavsum, devbuf[nc]);
                            state = States.S_M_MSGID;
                            break;
                        case States.S_M_MSGID:
                            cmd = (MSP.Cmds)devbuf[nc];
                            mavsum = mavlink_crc(mavsum, cmd);
                            if (csize == 0)
                                state = States.S_M_CRC1;
                            else
                                state = States.S_M_DATA;
                            break;
                        case States.S_M_DATA:
                            mavsum = mavlink_crc(mavsum, devbuf[nc]);
                            rxbuf[irxbufp++] = devbuf[nc];
                            needed--;
                            if(needed == 0)
                                state = States.S_M_CRC1;
                            break;
                        case States.S_M_CRC1:
                            mavsum = mavlink_crc(mavsum, MAVCRCS[cmd]);
                            irxbufp = 0;
                            rxmavsum = devbuf[nc];
                            state = States.S_M_CRC2;
                            break;
                        case States.S_M_CRC2:
                            rxmavsum |= (devbuf[nc] << 8);
                            if(rxmavsum == mavsum)
                            {
                                stats.msgs++;
                                serial_event (cmd+MSP.Cmds.MAV_BASE,
                                              rxbuf, csize, 0, errstate);
                                state = States.S_HEADER;
                            }
                            else
                            {
                                error_counter();
                                MWPLog.message("MAVCRC Fail, got %x != %x (cmd=%u, len=%u)\n",
                                               rxmavsum, mavsum, cmd, csize);
                                state = States.S_ERROR;
                            }
                            break;
                    }
                }
            }
        }
        return Source.CONTINUE;
    }

    public uint8 crc8_dvb_s2(uint8 crc, uint8 a)
    {
        crc ^= a;
        for (int i = 0; i < 8; i++)
        {
            if ((crc & 0x80) != 0)
                crc = (crc << 1) ^ 0xd5;
            else
                crc = crc << 1;
        }
        return crc;
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
        if(ro)
            return 0;

        if(stime == 0 && pmode == ProtoMode.NORMAL)
            stime =  GLib.get_monotonic_time();

        stats.txbytes += count;

        if((commode & ComMode.BT) == ComMode.BT)
            size = Posix.send(fd, buf, count, 0);
        else if((commode & ComMode.STREAM) == ComMode.STREAM)
            size = Posix.write(fd, buf, count);
        else
        {
            unowned uint8[] sbuf = (uint8[]) buf;
            sbuf.length = (int)count;
            try
            {
                size = skt.send_to (sockaddr, sbuf);
            } catch(Error e) {
//                stderr.printf("err::send: %s", e.message);
                size = 0;
            }
        }
        if(rawlog == true)
        {
            log_raw('o',buf,(int)count);
        }
        return size;
    }

    public void send_ltm(uint8 cmd, void *data, size_t len)
    {
        if(available == true && !ro)
        {
            if(len != 0 && data != null)
            {
                uint8 *ptx = txbuf;
                uint8* pdata = (uint8*)data;
                check_txbuf_size(len+4);
                uint8 ck = 0;
                *ptx++ ='$';
                *ptx++ = 'T';
                *ptx++ = cmd;
                for(var i = 0; i < len; i++)
                {
                    *ptx = *pdata++;
                    ck ^= *ptx++;
                }
                *ptx = ck;
                write(txbuf, (len+4));
            }
        }
    }


    public void send_mav(uint8 cmd, void *data, size_t len)
    {
        const uint8 MAVID1='j';
        const uint8 MAVID2='h';

        if(available == true && !ro)
        {
            uint16 mcrc;
            uint8* ptx = txbuf;
            uint8* pdata = data;

            check_txbuf_size(len+8);
            mcrc = mavlink_crc(0xffff, (uint8)len);

            *ptx++ = 0xfe;
            *ptx++ = (uint8)len;

            *ptx++ = mavseqno;
            mcrc = mavlink_crc(mcrc, mavseqno);
            mavseqno++;
            *ptx++ = MAVID1;
            mcrc = mavlink_crc(mcrc, MAVID1);
            *ptx++ = MAVID2;
            mcrc = mavlink_crc(mcrc, MAVID2);
            *ptx++ = cmd;
            mcrc = mavlink_crc(mcrc, cmd);
            for(var j = 0; j < len; j++)
            {
                *ptx = *pdata++;
                mcrc = mavlink_crc(mcrc, *ptx);
                ptx++;
            }
            mcrc = mavlink_crc(mcrc, MAVCRCS[cmd]);
            *ptx++ = (uint8)(mcrc&0xff);
            *ptx++ = (uint8)(mcrc >> 8);
            write(txbuf, (len+8));
        }
    }

    private size_t generate_v1(uint8 cmd, void *data, size_t len)
    {
        uint8 ck = 0;

        check_txbuf_size(len+6);
        uint8* ptx = txbuf;
        uint8* pdata = data;

        *ptx++ = '$';
        *ptx++ = 'M';
        *ptx++ = writedirn;
        ck ^= (uint8)len;
        *ptx++ = (uint8)len;
        ck ^=  cmd;
        *ptx++ = cmd;
        for(var i = 0; i < len; i++)
        {
            *ptx = *pdata++;
            ck ^= *ptx++;
        }
        *ptx  = ck;
        return len+6;
    }

    public size_t generate_v2(uint16 cmd, void *data, size_t len)
    {
        uint8 ck2=0;

        check_txbuf_size(len+9);

        uint8* ptx = txbuf;
        uint8* pdata = data;

        *ptx++ ='$';
        *ptx++ ='X';
        *ptx++ = writedirn;
        *ptx++ = 0; // flags
        ptx = serialise_u16(ptx, cmd);
        ptx = serialise_u16(ptx, (uint16)len);
        ck2 = crc8_dvb_s2(ck2, txbuf[3]);
        ck2 = crc8_dvb_s2(ck2, txbuf[4]);
        ck2 = crc8_dvb_s2(ck2, txbuf[5]);
        ck2 = crc8_dvb_s2(ck2, txbuf[6]);
        ck2 = crc8_dvb_s2(ck2, txbuf[7]);

        for (var i = 0; i < len; i++)
        {
            *ptx = *pdata++;
            ck2 = crc8_dvb_s2(ck2, *ptx);
            ptx++;
        }
        *ptx = ck2;
        return len+9;
    }

    public void send_command(uint16 cmd, void *data, size_t len)
    {
        if(available == true && !ro)
        {
            size_t mlen;
            if(use_v2 || cmd > 254 || len > 254)
                mlen = generate_v2(cmd,data,len);
            else
                mlen  = generate_v1((uint8)cmd, data, len);
            write(txbuf, mlen);
        }
    }

    public void send_error(uint8 cmd)
    {
        if(available == true && !ro)
        {
            uint8 dstr[8] = {'$', 'M', '!', 0, cmd, cmd};
            write(dstr, 6);
        }
    }

    private void log_raw(uint8 dirn, void *buf, int len)
    {
        double dt = timer.elapsed ();
        uint16 blen = (uint16)len;
        Posix.write(raws, &dt, sizeof(double));
        Posix.write(raws, &blen, 2);
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
            Posix.write(raws, "v2\n" , 3);
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
