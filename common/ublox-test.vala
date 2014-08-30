
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


/* Based on the Multiwii UBLOX parser, GPL by a cast of thousands */

// valac --pkg posix --pkg gio-2.0 --pkg posix  ublox.vapi ublox-test.vala -o ublox-test

public class MWSerial : Object
{
    public int fd {private set; get;}
    private IOChannel io_read;
    public  bool available {private set; get;}
    private uint tag;
    private Posix.termios oldtio;
    public uint baudrate  {private set; get;}

    private uint8 _ck_a;
    private uint8 _ck_b;

// State machine state
    private uint8 _step;
    private uint8 _msg_id;
    private bool _fix_ok;
    private double _speed;
    private double _course;
    private int _numsat;
    private uint8 _fixt;
    private uint16 _payload_length;
    private uint16 _payload_counter;
//  static bool next_fix;
    private uint8 _class;
    private unowned ublox_buffer _buffer;

    public enum UPXProto
    {
        PREAMBLE1 = 0xb5,
        PREAMBLE2 = 0x62,
        CLASS_NAV = 0x01,
        CLASS_ACK = 0x05,
        CLASS_CFG = 0x06,
        MSG_ACK_NACK = 0x00,
        MSG_ACK_ACK = 0x01,
        MSG_POSLLH = 0x2,
        MSG_STATUS = 0x3,
        MSG_SOL = 0x6,
        MSG_VELNED = 0x12,
        MSG_CFG_PRT = 0x00,
        MSG_CFG_RATE = 0x08,
        MSG_CFG_SET_RATE = 0x01,
        MSG_CFG_NAV_SETTINGS = 0x24
    }

    public enum UBXFix
    {
        FIX_NONE = 0,
            FIX_DEAD_RECKONING = 1,
            FIX_2D = 2,
            FIX_3D = 3,
            FIX_GPS_DEAD_RECKONING = 4,
            FIX_TIME = 5
    }

    public enum UBX_status_bits
    {
        NAV_STATUS_FIX_VALID = 1
    }

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
            if(ublox_parse(buf[nc]) == true)
            {
                display_fix();
            }
        }
        return true;
    }

    private void display_fix()
    {
        if(_fix_ok)
        {
            stdout.printf("lat: %f lon: %f elev: %f ",
                          _buffer.posllh.latitude/10000000.0,
                          _buffer.posllh.longitude/10000000.0,
                          _buffer.posllh.altitude_msl / 1000.0);
        }
        stdout.printf("sats: %d, fix %d\n", _numsat, _fixt);
    }

    private bool ublox_parse(uint8 data)
    {
        bool parsed = false;
        switch(_step)
        {
            case 1:
                if (UPXProto.PREAMBLE2 == data) {
                    _step++;
                    break;
                }
                _step = 0;
                if(UPXProto.PREAMBLE1 == data) _step++;
                break;
            case 0:
                if(UPXProto.PREAMBLE1 == data) _step++;
                break;
            case 2:
                _step++;
                _class = data;
                _ck_b = _ck_a = data;  // reset the checksum accumulators
                break;
            case 3:
                _step++;
                _ck_b += (_ck_a += data);  // checksum byte
                _msg_id = data;
                break;
            case 4:
                _step++;
                _ck_b += (_ck_a += data);  // checksum byte
                _payload_length = data;  // payload length low byte
                break;
            case 5:
                _step++;
                _ck_b += (_ck_a += data);  // checksum byte
                _payload_length += (uint16)(data<<8);
                if (_payload_length > 512) {
                    _payload_length = 0;
                    _step = 0;
                }
                _payload_counter = 0;  // prepare to receive payload
                break;
            case 6:
                _ck_b += (_ck_a += data);  // checksum byte
                if (_payload_counter < sizeof(ublox_buffer)) {
                    _buffer.xbytes[_payload_counter] = data;
                }
                if (++_payload_counter == _payload_length)
                    _step++;
                break;
            case 7:
                _step++;
                if (_ck_a != data) _step = 0;  // bad checksum
                break;
            case 8:
                _step = 0;
                if (_ck_b != data)  break;  // bad checksum
                parsed = ublox_parse_gps();
                if(parsed)
                {
                }
                break;
        }
        return parsed;
    }

    private bool ublox_parse_gps()
    {
        bool ret = false;
        switch (_msg_id)
        {
            case UPXProto.MSG_POSLLH:
                ret = true;
                break;
            case UPXProto.MSG_SOL:
                _fix_ok = (((_buffer.solution.fix_status & UBX_status_bits.NAV_STATUS_FIX_VALID) == UBX_status_bits.NAV_STATUS_FIX_VALID)
                           &&
                           (_buffer.solution.fix_type == UBXFix.FIX_3D
                            || _buffer.solution.fix_type ==UBXFix.FIX_2D));
                _fixt = _buffer.solution.fix_type;
                _numsat = _buffer.solution.satellites;
                break;
            case  UPXProto.MSG_VELNED:
                _speed = _buffer.velned.speed_2d/100.0;  // cm/s => m/s
                _course = (_buffer.velned.heading_2d / 100000.0);  // Heading 2D deg * 100000 rescaled to deg
                break;
            default:
                break;
        }
        return ret;
    }

    public void ublox_write(int fd, uint8[]data)
    {
        foreach(uint8 b in data)
        {
            Posix.write(fd, &b, 1);
            Thread.usleep(5);
        }
    }

    public static int main (string[] args)
    {
        var dev = (args.length > 1) ? args[1] : "/dev/ttyUBS0";
        var baud = int.parse((args.length > 2) ? args[2] : "115200");
        uint32 [] init_speed = {9600,19200,38400,57600,115200};
        uint8 [] init =
            {
                0xB5,0x62,0x06,0x01,0x03,0x00,0xF0,0x05,0x00,0xFF,0x19,
                /*disable all default NMEA messages*/
            0xB5,0x62,0x06,0x01,0x03,0x00,0xF0,0x03,0x00,0xFD,0x15,
            0xB5,0x62,0x06,0x01,0x03,0x00,0xF0,0x01,0x00,0xFB,0x11,
            0xB5,0x62,0x06,0x01,0x03,0x00,0xF0,0x00,0x00,0xFA,0x0F,
            0xB5,0x62,0x06,0x01,0x03,0x00,0xF0,0x02,0x00,0xFC,0x13,
            0xB5,0x62,0x06,0x01,0x03,0x00,0xF0,0x04,0x00,0xFE,0x17,
            0xB5,0x62,0x06,0x01,0x03,0x00,0x01,0x02,0x01,0x0E,0x47,                            /*set POSLLH MSG rate*/
            0xB5,0x62,0x06,0x01,0x03,0x00,0x01,0x03,0x01,0x0F,0x49,                            /*set STATUS MSG rate*/
            0xB5,0x62,0x06,0x01,0x03,0x00,0x01,0x06,0x01,0x12,0x4F,                            /*set SOL MSG rate*/
            0xB5,0x62,0x06,0x01,0x03,0x00,0x01,0x12,0x01,0x1E,0x67,                            /*set VELNED MSG rate*/
            0xB5,0x62,0x06,0x16,0x08,0x00,0x03,0x07,0x03,0x00,0x51,0x08,0x00,0x00,0x8A,0x41,   /*set WAAS to EGNOS*/
            0xB5, 0x62, 0x06, 0x08, 0x06, 0x00, 0xC8, 0x00, 0x01, 0x00, 0x01, 0x00, 0xDE, 0x6A /*set rate to 5Hz*/
            };

        var s = new MWSerial();
        var ml = new MainLoop();

        Timeout.add(100, () => {
                var str="";

                if(baud == 19200)
                    str = "$PUBX,41,1,0003,0001,19200,0*23\r\n";
                else if (baud == 38400)
                    str= "$PUBX,41,1,0003,0001,38400,0*26\r\n";
                else if (baud == 57600)
                    str = "$PUBX,41,1,0003,0001,57600,0*2D\r\n";
                else if (baud == 115200)
                    str = "$PUBX,41,1,0003,0001,115200,0*1E\r\n";

                foreach (var rate in init_speed)
                {
                    s.open(dev,rate);
                    s.ublox_write(s.fd, str.data);
                    Thread.usleep(10000);
                    s.close();
                }
                s.open(dev,baud);
                s.ublox_write(s.fd, init);
                return false;
            });
        ml.run();
        return 0;
    }
}
