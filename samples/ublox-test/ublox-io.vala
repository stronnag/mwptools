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

extern int open_serial(string dev, int baudrate);
extern void set_fd_speed(int fd, int baudrate);
extern void close_serial(int fd);
extern string default_name();
extern unowned string get_error_text(int err, uint8[] buf, size_t len);

public class MWSerial : Object
{
    public struct SerialStats
    {
        double elapsed;
        ulong rxbytes;
        ulong txbytes;
        double rxrate;
        double txrate;
    }
    public int fd {private set; get;}
    private IOChannel io_read;
    public  bool available {private set; get;}
    private uint tag;
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
    private uint8 _class;
    private uint8 nmea_state = 0;
    private uint8 nmea_idx = 0;
    private uint8 nmea_buf[128];
    private SerialStats stats;

    private unowned ublox_buffer _buffer;
    private int gpsvers = 0;
    private Timer timer;

    private int64 stime;
    private int64 ltime;

    public static string devname = null;
    public static int brate = 38400;
    private static bool ureset = false;
    private static bool force6 = false;
    private static int air_model = 1;
    private static bool force_10hz = false;
    private static bool noinit = false;
    private static bool noautob = false;
    private static bool slow = false;
    private static bool pass = false;
    private static bool galileo = false;

    const OptionEntry[] options = {
        { "device", 'd', 0, OptionArg.STRING, out devname, "device name", "/dev/ttyUSB0"},
        { "baudrate", 'b', 0, OptionArg.INT, out brate, "Baud rate", "38400"},
        { "reset", 'r', 0, OptionArg.NONE, out ureset, "Reset device", null},
        { "no-init", 'n', 0, OptionArg.NONE, out noinit, "No init", null},
        { "no-autobaud", 'N', 0, OptionArg.NONE, out noautob, "No autobaud", null},
        { "force-v6", '6', 0, OptionArg.NONE, out force6, "Force V6 init (vice inav autodetect)", null},
        { "air-model", 'a', 0, OptionArg.INT, out air_model, "0,1,4", null},
        { "force-10hz", 'z', 0, OptionArg.NONE, out force_10hz, "Force 10Hz", null},
        { "slow", 's', 0, OptionArg.NONE, out slow, "slower initialisation", null},
        { "pass", 'p', 0, OptionArg.NONE, out pass, "cf gps passthrough", null},
        { "galileo", 'g', 0, OptionArg.NONE, out galileo, "enable Galileo", null},
        {null}
    };

    public struct UBLOX_UPD
    {
        bool fix_ok;
        int numsat;
        uint8 fixt;
        double gpslat;
        double gpslon;
        double gpsalt;
        double gpshacc;
        double gpsvacc;
        string date;
    }

    private UBLOX_UPD u;

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
        MSG_SVINFO = 0x30,
        MSG_SOL = 0x6,
        MSG_VELNED = 0x12,
        MSG_CFG_PRT = 0x00,
        MSG_CFG_RATE = 0x08,
        MSG_CFG_SET_RATE = 0x01,
        MSG_CFG_NAV_SETTINGS = 0x24,
        UBX_NAV_PVT = 0x07
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

    public signal void gps_update (UBLOX_UPD u);

    public enum State
    {
        SPEED0 = 0,
        SPEED1,
        SPEED2,
        SPEED3,
        SPEED4,
        BAUDRATE,
        START,
        V7INIT,
        MOTION,
        POS,
        TIMEUTC,
        GALILEO,
        RATE,
        SBAS
    }

    public int gps_state = State.START;

    public MWSerial()
    {
        available = false;
        fd = -1;
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

    private bool open(string device, int rate)
    {
        fd = open_serial(device, rate);
        if(fd < 0)
        {
            uint8 [] sbuf = new uint8[1024];
            var lasterr=Posix.errno;
            var s = get_error_text(lasterr, sbuf, 1024);
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
            close_serial(fd);
            fd = -1;
        }
    }

    private bool device_read(IOChannel gio, IOCondition cond) {
        uint8 buf[2048];
        size_t res;
        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0)
        {
            available = false;
            return false;
        }
        else
        {
            res = Posix.read(fd,buf,2048);
            if(res == 0)
                return true;
        }
        for(var nc = 0; nc < res; nc++)
        {
            stats.rxbytes++;
            if(ublox_parse(buf[nc]) == true)
            {
                gps_update (u);
            }
        }
        return true;
    }

    private void display_fix()
    {
        stdout.printf("POSLLH: lat: %f lon: %f elev: %.2f acc(h/v): %.1f/%.1f\n",
                      _buffer.posllh.latitude/10000000.0,
                      _buffer.posllh.longitude/10000000.0,
                      _buffer.posllh.altitude_msl / 1000.0,
                      _buffer.posllh.horizontal_accuracy/1000.0,
                      _buffer.posllh.vertical_accuracy/1000.0
                      );
        stdout.printf("sats: %d, fix %d\n", _numsat, _fixt);
        if(_fix_ok)
        {
            u.gpslat = _buffer.posllh.latitude/10000000.0;
            u.gpslon = _buffer.posllh.longitude/10000000.0;
            u.gpsalt = _buffer.posllh.altitude_msl / 1000.0;
            u.gpshacc = _buffer.posllh.horizontal_accuracy/1000.0;
            u.gpsvacc = _buffer.posllh.vertical_accuracy/1000.0;
        }
        u.numsat = _numsat;
        u.fixt = _fixt;
        u.fix_ok = _fix_ok;
    }

    private void display_fix7()
    {
        stdout.printf("PVT: lat: %f lon: %f elev: %.2f acc(h/v): %.1f/%.1f\n",
                          _buffer.pvt.latitude/10000000.0,
                          _buffer.pvt.longitude/10000000.0,
                          _buffer.pvt.altitude_msl / 1000.0,
                          _buffer.pvt.horizontal_accuracy/1000.0,
                          _buffer.pvt.vertical_accuracy/1000.0
                          );
        stdout.printf("sats: %d, fix %d\n", _buffer.pvt.satellites, _buffer.pvt.fix_type);
        int32 nano =  ( _buffer.pvt.nano +999999) /1000000;
        u.date = "%04d-%02d-%02d %02d:%02d:%02d.%03d".printf( _buffer.pvt.year,
                                                              _buffer.pvt.month,
                                                              _buffer.pvt.day,
                                                              _buffer.pvt.hour,
                                                              _buffer.pvt.min,
                                                              _buffer.pvt.sec,
                                                              nano);
        stdout.printf("%s\n", u.date);
        if(_fix_ok)
        {
            u.fix_ok = true;
            u.gpslat = _buffer.pvt.latitude/10000000.0;
            u.gpslon = _buffer.pvt.longitude/10000000.0;
            u.gpsalt = _buffer.pvt.altitude_msl / 1000.0;
            u.gpshacc = _buffer.pvt.horizontal_accuracy/1000.0;
            u.gpsvacc = _buffer.pvt.vertical_accuracy/1000.0;
            u.numsat = _buffer.pvt.satellites;
            u.fixt = _buffer.pvt.fix_type;
        }
    }

    private bool ublox_parse(uint8 data)
    {
        bool parsed = false;
        switch(_step)
        {
            case 0:
                if(UPXProto.PREAMBLE1 == data)
                    _step++;
                else
                {
                    switch(nmea_state)
                    {
                        case 0:
                            if(data == '$')
                            {
                                nmea_idx = 0;
                                nmea_buf[nmea_idx++] = data;
                                nmea_state++;
                            }
                            break;
                        case 1:
                            if(data == 'G')
                            {
                                nmea_buf[nmea_idx++] = data;
                                nmea_state++;
                            }
                            else
                                nmea_state = nmea_idx = 0;
                            break;
                        case 2:
                            if(data == '\r')
                            {
                                nmea_state++;
                            }
                            else
                            {
                                nmea_buf[nmea_idx++] = data;
                            }
                            break;
                        case 3:
                            if(data == '\n')
                            {
                                nmea_state = 0;
                                nmea_buf[nmea_idx++] = data;
                                nmea_buf[nmea_idx] = 0;
                                stdout.puts((string)nmea_buf);
                            }
                            nmea_state = 0;
                            break;
                    }
                }
                break;
            case 1:
                if (UPXProto.PREAMBLE2 == data) {
                    _step++;
                    break;
                }
                _step = 0;
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
                break;
        }
        return parsed;
    }

    private bool ublox_parse_gps()
    {
        bool ret = false;
        if(_class != 5)
            stdout.printf("Data size %db (%x %x)\n",
                          _payload_length, _class, _msg_id);
        if(_class == 1)
        {
            switch (_msg_id)
            {
                case UPXProto.MSG_SVINFO:
                    stdout.printf("SVINFO: Channels %d\n", _buffer.svinfo.numch);
                    for(var i = 0; i < _buffer.svinfo.numch; i++)
                    {
                        string gnssid;
                        var sv = _buffer.svinfo.svitems[i];
                        var svid = sv.svid;
                        if (svid >= 1 && svid <= 32)
                            gnssid = "G%d".printf(svid);
                        else if (svid >= 120 && svid <= 158)
                            gnssid = "SBAS%d".printf(svid-119);
                        else if (svid >= 211 && svid <= 246)
                            gnssid = "E%d".printf(svid-210);
                        else if (svid >= 159 && svid <= 163)
                            gnssid = "B%d".printf(svid-158);
                        else if (svid >= 33 && svid <= 64)
                            gnssid = "B%d".printf(svid-26);
                        else if (svid >= 173 && svid <= 182)
                            gnssid = "I%d".printf(svid-182);
                        else if (svid >= 193 && svid <= 197)
                            gnssid = "Q%d".printf(svid-192);
                        else if (svid >= 65 && svid <= 96)
                            gnssid = "R%d".printf(svid-64);
                        else
                            gnssid = "????";
                        stdout.printf("%2d %6.6s %s %s %d\n",
                                      sv.chn,
                                      gnssid,
                                      ((sv.flags & 1) == 1) ? "Y" : "-",
                                      ((sv.flags & 2) == 2) ? "Y" : "-",
                                      sv.quality);
                    }
                    break;
                case UPXProto.MSG_POSLLH:
                    display_fix();
                    ret = true;
                    break;
                case UPXProto.UBX_NAV_PVT:
                    _fix_ok = (((_buffer.pvt.fix_status & UBX_status_bits.NAV_STATUS_FIX_VALID) == UBX_status_bits.NAV_STATUS_FIX_VALID)
                               &&
                               (_buffer.pvt.fix_type == UBXFix.FIX_3D
                                || _buffer.pvt.fix_type ==UBXFix.FIX_2D));

                    display_fix7();
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
                case 0x21: //NAV-TIMEUTC
                    u.date = "%04d-%02d-%02d %02d:%02d:%02d".printf(
                        _buffer.timeutc.year,
                        _buffer.timeutc.month,
                        _buffer.timeutc.day,
                        _buffer.timeutc.hour,
                        _buffer.timeutc.min,
                        _buffer.timeutc.sec);
                    stdout.printf("TIMEUTC: %s valid=%x\n", u.date, _buffer.timeutc.valid);
                    break;
                default:
                    break;
            }
        }
        else if(_class == 0x0a && _msg_id == 4)
        {
            var dt = timer.elapsed ();
            stdout.printf("Version info after %fs (%db)\n", dt, _payload_length);
            unowned uint8*v2 = &_buffer.xbytes[30];
            gpsvers = int.parse((string)(v2));
            stdout.printf("SW: %s HW: %s %d\n", (string)_buffer.xbytes,
                          (string)v2,gpsvers);
                // V8 Extended versioning
            if(_payload_length > 40)
            {
                for(int n = 40; n < _payload_length; n+= 30)
                {
                    v2 = &_buffer.xbytes[n];
                    stdout.printf("ExtVer:  %s\n", (string)v2);
                }
            }
        }
        return ret;
    }

    public void ublox_write(int fd, uint8[]data)
    {
        foreach(uint8 b in data)
        {
            Posix.write(fd, &b, 1);
            stats.txbytes++;
            Thread.usleep(10);
        }
    }

    private string get_gps_speed_string()
    {
        var str = "";
        switch (brate)
        {
            case 115200:
                str = "$PUBX,41,1,0003,0001,115200,0*1E\r\n";
                break;
            case 57600:
                str = "$PUBX,41,1,0003,0001,57600,0*2D\r\n";
                break;
            case 38400:
                str = "$PUBX,41,1,0003,0001,38400,0*26\r\n";
                break;
            case 19200:
                str = "$PUBX,41,1,0003,0001,19200,0*23\r\n";
                break;
            case 9600:
                str = "$PUBX,41,1,0007,0003,9600,0*10\r\n";
                break;
        }
        return str;
    }

    public bool ublox_open(string devname, int brate)
    {
        string [] parts;

        parts = devname.split ("@");
        if(parts.length == 2)
        {
            devname = parts[0];
            brate = int.parse(parts[1]);
        }

        stdout.printf("%s@%d\n", devname, brate);

        open(devname, brate);
        if(available)
        {
            gps_state = 0;
            init_timer();
            if(pass)
            {
                stdout.printf("Passthrough\n");
                ublox_write(fd,"#\n".data);
                Thread.usleep(1000*100);
                ublox_write(fd,"gpspassthrough\n".data);
                Thread.usleep(1000*100);
                Posix.tcflush(fd, Posix.TCIOFLUSH);
                gps_state = State.START;
                Timeout.add(100, () => {
                        return setup_gps();
                    });
            }
            else
            {
                var delay = 100;
                if(slow)
                    delay = 200;
                Timeout.add(delay, () => {
                        Posix.tcflush(fd, Posix.TCIOFLUSH);
                        return setup_gps();
                    });
            }
        }
        return available;
    }

    private bool setup_gps()
    {
        uint8 [] pedestrain = {
            0xB5, 0x62, 0x06, 0x24, 0x24, 0x00, 0xFF, 0xFF, 0x03, 0x03, 0x00,           // CFG-NAV5 - Set engine settings (original MWII code)
            0x00, 0x00, 0x00, 0x10, 0x27, 0x00, 0x00, 0x05, 0x00, 0xFA, 0x00,           // Collected by resetting a GPS unit to defaults. Changing mode to Pedistrian and
            0xFA, 0x00, 0x64, 0x00, 0x2C, 0x01, 0x00, 0x3C, 0x00, 0x00, 0x00,           // capturing the data from the U-Center binary console.
            0x00, 0xC8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17, 0xC2
        };
        uint8 [] air1g = {
            0xB5, 0x62, 0x06, 0x24, 0x24, 0x00, 0xFF, 0xFF, 0x06, 0x03, 0x00,           // CFG-NAV5 - Set engine settings
            0x00, 0x00, 0x00, 0x10, 0x27, 0x00, 0x00, 0x05, 0x00, 0xFA, 0x00,           // Airborne <1G
            0xFA, 0x00, 0x64, 0x00, 0x2C, 0x01, 0x00, 0x3C, 0x00, 0x00, 0x00,
            0x00, 0xC8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1A, 0x28
        };
        uint8 [] air4g = {
            0xB5, 0x62, 0x06, 0x24, 0x24, 0x00, 0xFF, 0xFF, 0x08, 0x03, 0x00,           // CFG-NAV5 - Set engine settings
            0x00, 0x00, 0x00, 0x10, 0x27, 0x00, 0x00, 0x05, 0x00, 0xFA, 0x00,           // Airborne <4G
            0xFA, 0x00, 0x64, 0x00, 0x2C, 0x01, 0x00, 0x3C, 0x00, 0x00, 0x00,
            0x00, 0xC8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1C, 0x6C
        };

        uint8 [] nonmea = {
                // DISABLE NMEA messages
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0xF0, 0x05, 0x00, 0xFF, 0x19,           // VGS: Course over ground and Ground speed
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0xF0, 0x03, 0x00, 0xFD, 0x15,           // GSV: GNSS Satellites in View
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0xF0, 0x01, 0x00, 0xFB, 0x11,           // GLL: Latitude and longitude, with time of position fix and status
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0xF0, 0x00, 0x00, 0xFA, 0x0F,           // GGA: Global positioning system fix data
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0xF0, 0x02, 0x00, 0xFC, 0x13,           // GSA: GNSS DOP and Active Satellites
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0xF0, 0x04, 0x00, 0xFE, 0x17            // RMC: Recommended Minimum data
        };

        uint8 [] posllh = {
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0x01, 0x02, 0x01, 0x0E, 0x47,           // set POSLLH MSG rate
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0x01, 0x03, 0x01, 0x0F, 0x49,           // set STATUS MSG rate
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0x01, 0x06, 0x01, 0x12, 0x4F,           // set SOL MSG rate
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0x01, 0x30, 0x05, 0x40, 0xA7,           // set SVINFO MSG rate (evey 5 cycles - low bandwidth)
            0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0x01, 0x12, 0x01, 0x1E, 0x67            // set VELNED MSG rate
        };

        uint8 [] gnss_galileo =
            {
                0xb5, 0x62, 0x06, 0x3e, 0x3c, 0x00, 0x00, 0x00, 0x20, 0x07,
                0x00, 0x08, 0x10, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x01,
                0x03, 0x00, 0x01, 0x00, 0x01, 0x01, 0x02, 0x04, 0x08, 0x00,
                0x01, 0x00, 0x01, 0x01, 0x03, 0x08, 0x10, 0x00, 0x00, 0x00,
                0x01, 0x01, 0x04, 0x00, 0x08, 0x00, 0x00, 0x00, 0x01, 0x01,
                0x05, 0x00, 0x03, 0x00, 0x01, 0x00, 0x01, 0x01, 0x06, 0x08,
                0x0e, 0x00, 0x01, 0x00, 0x01, 0x01, 0x30, 0xad
            };

        uint8 [] pvt = {
                0xB5, 0x62, 0x06, 0x01, 0x08, 0x00, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0xB9, // disable POSLLH
    0xB5, 0x62, 0x06, 0x01, 0x08, 0x00, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13, 0xC0, // disable STATUS
    0xB5, 0x62, 0x06, 0x01, 0x08, 0x00, 0x01, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x16, 0xD5, // disable SOL
    0xB5, 0x62, 0x06, 0x01, 0x08, 0x00, 0x01, 0x30, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x4A, 0x2D, // enable SVINFO 10 cycle
    0xB5, 0x62, 0x06, 0x01, 0x08, 0x00, 0x01, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x22, 0x29, // disable VELNED
    0xB5, 0x62, 0x06, 0x01, 0x08, 0x00, 0x01, 0x07, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x18, 0xE1  // enable PVT 1 cycle
        };
        uint8 [] rate_5hz = {
    0xB5, 0x62, 0x06, 0x08, 0x06, 0x00, 0xC8, 0x00, 0x01, 0x00, 0x01, 0x00, 0xDE, 0x6A  // set rate to 5Hz (measurement period: 200ms, navigation rate: 1 cycle)
        };
        uint8 [] rate_10hz = {
            0xB5, 0x62, 0x06, 0x08, 0x06, 0x00, 0x64, 0x00, 0x01, 0x00, 0x01, 0x00, 0x7A, 0x12, // set rate to 10Hz (measurement period: 100ms, navigation rate: 1 cycle)
        };
       uint8 [] timeutc = {0xB5, 0x62, 0x06, 0x01, 0x03, 0x00, 0x01, 0x21, 0x05, 0x31, 0x89 };
        uint8 [] reset = {0xB5, 0x62, 0x06, 0x04, 0x04, 0x00, 0xFF, 0x87,
                          0x00, 0x00, 0x94, 0xF5};
        uint8 [] sbas = {
            /* SBAS_AUTO */  0xB5, 0x62, 0x06, 0x16, 0x08, 0x00, 0x03, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2D, 0xC9
        };
        int [] init_speed = {115200, 57600, 38400, 19200, 9600};
        uint8 [] v7init = {0xB5, 0x62, 0x0A, 0x04, 0x00, 0x00, 0x0E, 0x34 };


        bool ret = true;

        switch (gps_state)
        {
            case State.SPEED0:
            case State.SPEED1:
            case State.SPEED2:
            case State.SPEED3:
            case State.SPEED4:
                if(noautob == false)
                {
                    var str = get_gps_speed_string();
                    set_fd_speed(fd, init_speed[gps_state]);
                    ublox_write(fd, str.data);
                    gps_state++;
                }
                else
                    gps_state = State.BAUDRATE;
                break;

            case State.BAUDRATE:
                stdout.printf("Rate initialised %d\n", brate);
                set_fd_speed(fd, brate);
                gps_state++;
                break;

            case State.V7INIT:
                if(noinit == false)
                {
                    timer = new Timer ();
                    stdout.puts("Request version\n");
                    ublox_write(fd, v7init);
                }
                gps_state++;
                break;

            case State.START:
                    if(ureset)
                    {
                        stdout.puts("send hard reset\n");
                        ublox_write(fd, reset);
                        ret = true;
                    }
                    else if(noinit == false)
                    {
                        stdout.printf("Disable NMEA\n");
                        ublox_write(fd, nonmea); // 2
                        gps_state++;
                    }
                    else
                    {
                        stdout.printf("No init requested\n");
                        ret = true;
                    }
                    break;
            case State.MOTION:
                switch(air_model)
                {
                    case 0:
                        stdout.printf("Set pedestrian\n");
                        ublox_write(fd, pedestrain);
                        break;
                    case 4:
                        stdout.printf("Set air 4G\n");
                        ublox_write(fd, air4g);
                        break;
                    default:
                        stdout.printf("Set air 1G\n");
                        ublox_write(fd, air1g);
                        break;
                }
                gps_state++;
                break;
            case State.POS:
                if(force6 || gpsvers < 70000) //3
                {
                    stdout.printf("send INAV ublox v6 init [%d] POSLLH\n", gpsvers);
                    ublox_write(fd, posllh);
                }
                else
                {
                    ublox_write(fd, pvt);
                    stdout.printf("send INAV ublox v7 init [%d] PVT\n", gpsvers);
                    gps_state++;
                }
                gps_state++;
                break;
            case State.TIMEUTC:
                stdout.printf("Set Neo 6 TimeUTC\n");
                ublox_write(fd, timeutc);
                gps_state++;
                break;

            case State.GALILEO:
                if (galileo && (gpsvers >= 70000))
                {
                    stdout.printf("Set galileo\n");
                    ublox_write(fd, gnss_galileo);
                }
                gps_state++;
                break;
            case State.RATE:
                if(force_10hz && (gpsvers >= 70000 ))
                {
                    stdout.printf("Set 10Hz\n");
                    ublox_write(fd, rate_10hz);
                }
                else
                {
                    stdout.printf("Set 5Hz\n");
                    ublox_write(fd, rate_5hz);
                }
                gps_state++;
                break;
            case State.SBAS:
                stdout.printf("Set SBAS\n");
                ublox_write(fd, sbas);
                ret = false;
                break;
        }
        return ret;
    }

    public int parse_option(string [] args)
    {
        try {
            var opt = new OptionContext("");
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

        if(devname == null)
            devname = default_name();
        return 0;
    }

    public void init_timer()
    {
        stime = GLib.get_monotonic_time();
    }

    public SerialStats getstats()
    {
        if(stime == 0)
            stime =  GLib.get_monotonic_time();
        ltime =  GLib.get_monotonic_time();
        stats.elapsed = (ltime - stime)/1000000.0;
        if (stats.elapsed > 0)
        {
            stats.txrate = stats.txbytes / stats.elapsed;
            stats.rxrate = stats.rxbytes / stats.elapsed;
        }
        return stats;
    }
}
