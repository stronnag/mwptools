
// valac --pkg gio-2.0 frsky.vala

public class Frsky : Object
{
    enum FrID {
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

    enum FrProto {
        P_START = 0x7e,
        P_STUFF = 0x7d,
        P_MASK  = 0x20,
        P_SIZE = 10
    }

    public double ax = 0;
    public double ay = 0;
    public double az = 0;

    public uint64 offset = 0;

    private bool fr_checksum(uint8[] buf)
    {
        uint16 crc = 0;
        for(var i = 2; i < FrProto.P_SIZE; i++)
        {
            crc += buf[i];
            crc += crc >> 8;
            crc &= 0xff;
        }
        return (crc == 0xff);
    }

    private double parse_lat_lon(uint val)
    {
        int value = (int)(val & 0x3fffffff);
        if ((val & (1 << 30))!= 0)
            value = -value;
        value = (5*value) / 3; // min/10000 => deg/1000000
        double dpos;
        dpos = value/ 1000000.0;
        return dpos;
    }

    private void sport_roll_pitch(out double pitch, out double roll)
    {
        pitch = 180.0 * Math.atan2 (ax, Math.sqrt(ay*ay + az*az))/Math.PI;
        roll  = 180.0 * Math.atan2 (ay, Math.sqrt(ax*ax + az*az))/Math.PI;
    }

    private void display_data(FrID id, uint val)
    {
        double r;
        switch(id)
        {
            case FrID.ACCX_ID:
                ax = ((int)val) / 100.0;
                break;
            case FrID.ACCY_ID:
                ay = ((int)val) / 100.0;
                break;
            case FrID.ACCZ_ID:
                az = ((int)val) / 100.0;
                double roll, pitch;
                sport_roll_pitch(out pitch, out roll);
                stdout.printf("ROLL %.2f PITCH %.2f\n",roll, pitch);
                break;
            case FrID.VFAS_ID:
                r = val / 100.0;
                stdout.printf("%s %.1f V\n", id.to_string(), r);
                break;
            case FrID.GPS_LONG_LATI_ID:
                var d = parse_lat_lon (val);
                stdout.printf("%s %.6f\n", id.to_string(), d);
                break;
            case FrID.GPS_ALT_ID:
                r =((int)val) / 100.0;
                stdout.printf("%s %.1f m\n", id.to_string(), r);
                break;
            case FrID.GPS_SPEED_ID:
                r = ((val/1000.0)*0.51444444);
                stdout.printf("%s %.2f m/s\n", id.to_string(), r);
                break;
            case FrID.GPS_COURS_ID:
                r = val / 100.0;
                stdout.printf("%s %.1f°\n", id.to_string(), r);
                break;
            case FrID.ADC2_ID: // AKA HDOP
                r = (val & 0xff) / 10.0;
                stdout.printf("%s %.1f (hdop)\n", id.to_string(), r);
                break;
            case FrID.ALT_ID:
                r = val / 100.0;
                stdout.printf("%s %.2f m/s\n", id.to_string(), r);
                break;
            case FrID.T1_ID: // flight modes
                uint ival = val;
                bool armOK = false;
                bool armed = false;
                string fmode = "";
                string nmode = "";
                string emode = "";
                for(var j = 0; j < 5; j++)
                {
                    uint mode = ival % 10;
                    switch(j)
                    {
                        case 0: // 1s
                            if((mode & 1) == 1)
                                armOK = true;
                            if ((mode & 4) == 4)
                                armed = true;
                            break;
                        case 1: // 10s
                            if(mode == 1)
                                fmode = "Angle";
                            else if(mode == 2)
                                fmode = "Horizon";
                            else if(mode == 4)
                                fmode = "Manual";
                            break;
                        case 2: // 100s
                            StringBuilder sb = new StringBuilder();
                            if((mode & 1) == 1)
                                sb.append("Heading ");
                            if((mode & 2) == 2)
                                sb.append("Althold ");
                            if((mode & 4) == 4)
                                sb.append("PosHold");
                            nmode = sb.str.strip();
                            break;
                        case 3: // 1000s
                            if(mode == 1)
                                nmode = "RTH";
                            if(mode == 2)
                                nmode = "WP";
                            if(mode == 4)
                                nmode = "HEADFREE";
                            if(mode == 8)
                                nmode = "CRUISE";
                            break;
                        case 4: // 10000s
                            if(mode == 2)
                                emode = "AUTOTUNE";
                            if(mode == 4)
                                emode = "FAILSAFE";
                            break;
                    }
                    ival = ival / 10;
                }
                stdout.printf("%s armOK:%s armed:%s %s %s %s\n", id.to_string(),
                              armOK.to_string(), armed.to_string(),
                              fmode, nmode, emode);
                break;
            case FrID.T2_ID: // GPS info
                uint nsats = val % 100;
                uint8 gfix = (uint8)(val /1000);
                uint16 hdp;
                hdp = (uint16)(val % 1000)/100;
                uint16 rhdop = 550 - (hdp * 50);
                stdout.printf("%s %u sats %u, fix %u %u %u\n", id.to_string(), val, nsats, gfix, hdp, rhdop);
                if((gfix & 4) == 4)
                    stdout.printf("Home reset at offset %s\n", offset.to_string());

                break;
            case FrID.RSSI_ID:
                    // http://ceptimus.co.uk/?p=271
                    // states main (Rx) link quality 100+ is full signal
                    // 40 is no signal
                    // iNav uses 0 - 1023
                uint rssi;
                uint issr;
                rssi = (val & 0xff);
                if (rssi > 100)
                    rssi = 100;
                if (rssi < 40)
                    rssi = 40;
                issr = (rssi - 40)*1023/60;
                stdout.printf("%s %u (%u %u)\n", id.to_string(), val, rssi, issr);
                break;
            case FrID.PITCH:
                r =((int)val) / 10.0;
                stdout.printf("%s %.1f m\n", id.to_string(), r);
                break;
            case FrID.ROLL:
                r =((int)val) / 10.0;
                stdout.printf("%s %.1f m\n", id.to_string(), r);
                break;
            case FrID.HOME_DIST:
                stdout.printf("%s %u m\n", id.to_string(), val);
                break;

            case FrID.CURR_ID:
                r =((int)val) / 10.0;
                stdout.printf("%s %.1f A\n", id.to_string(), r);
                break;

            case FrID.VARIO_ID:
                r = ((int)val) / 100.0;
                stdout.printf("%s %.2f m/s\n", id.to_string(), r);
                break;

                    /* not handling */
           case FrID.FUEL_ID:
                stdout.printf("%s %u (units unknown)\n", id.to_string(), val);
                break;

          case FrID.CELLS_ID:
            case FrID.RPM_ID:
            case FrID.GPS_TIME_DATE_ID:
            case FrID.A3_ID:
            case FrID.AIR_SPEED_ID:
            case FrID.RBOX_BATT1_ID:
            case FrID.RBOX_BATT2_ID:
            case FrID.RBOX_STATE_ID:
            case FrID.RBOX_CNSP_ID:
            case FrID.DIY_ID:
            case FrID.FUEL_QTY_ID:
            case FrID.ADC1_ID:
            case FrID.SP2UART_A_ID:
            case FrID.SP2UART_B_ID:
//            stderr.printf("Unhandled %s, raw value %u\n", id.to_string(), val);
                break;
            case FrID.XJT_VERSION_ID:
                stdout.printf("%s %u.%u\n", id.to_string(),
                              ((val & 0xffff) >> 8), (val & 0xff));
                break;
            case FrID.A4_ID:
            case FrID.BATT_ID:
                    // not sure these are useful, due to internal scaling
            case FrID.SWR_ID:
//            stdout.printf("%s %u\n", id.to_string(), (val & 0xff));
                break;
            default:
                stdout.printf("Unknown %04x, value %u\n", id, val);
                break;
        }
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

    public bool check_buffer(uint8[] buf)
    {
        bool res = fr_checksum(buf);
        if(res)
        {
            ushort id;
            uint val;
                /* fixme serialisation */
            deserialise_u16(buf+3, out id);
            deserialise_u32(buf+5, out val);
            display_data((FrID)id,val);
        }
        return res;
    }

    public static int main (string? []args)
    {
        uint good = 0;
        uint bad = 0;
        uint nshort = 0;
        int dist[256] = {0};

        var fr = new Frsky();

        try
        {
            var file = File.new_for_commandline_arg (args[1]);
            var file_stream = file.read ();
            var dis= new DataInputStream (file_stream);
            dis.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);
            uint8 buf[256];
            bool stuffed = false;
            uint8 nb = 0;
            int bp=-1;

            while (true)
            {
                uint8 b = dis.read_byte ();
                bp++;
                if (b == FrProto.P_START)
                {
                    if (nb >= FrProto.P_SIZE)
                    {
                        var res = fr.check_buffer(buf);
                        if (res)
                        {
                            good++;
                            for(var j = 0; j < nb; j++)
                            {
                                stderr.printf("%02x ", buf[j]);
                            }
                            stderr.putc('\n');
                        }
                        else
                            bad++;
                        fr.offset = bp;
                    }
                    else if (bp >  0)
                    {
                        nshort++;
                    }
                    if (nb < 256)
                        dist[nb] += 1;

                    nb = 0;
                }
                if (stuffed)
                {
                    b = b ^ FrProto.P_MASK;
                    stuffed = false;
                }
                else if (b == FrProto.P_STUFF)
                {
                    stdout.printf("Stuffed at offset %s\n", fr.offset.to_string());
                    stuffed = true;
                    continue;
                }
                buf[nb] = b;
                nb++;
            }
        }
        catch
        {
        }
        stdout.printf("total %u, good %u, bad %u, short %u\n", (good+bad+nshort),
                      good,bad,nshort);
        print("Size\tInstances\n~~~~\t~~~~~~~~~\n");
        for(var j = 0; j < 256; j++)
            if(dist[j] != 0)
                print("%2d:\t%8d\n", j, dist[j]);
        return 0;
    }
}
