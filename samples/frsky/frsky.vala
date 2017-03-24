
// valac --pkg gio-2.0 frsky.vala

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
    FUEL_QTY_ID = 0x0a10
}

enum FrProto {
    P_START = 0x7e,
    P_STUFF = 0x7d,
    P_MASK  = 0x20,
    P_SIZE = 10
}

bool fr_checksum(uint8[] buf)
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

string parse_lat_lon(uint val)
{
    uint8 ind = (uint8)(val >> 30);
    val &= 0x3fffffff ;
    uint16 bp ;
    uint16 ap ;
    uint32 parts ;

    parts = val / 10000 ;
    bp = (uint16)(parts / 60 * 100) + (uint16)(parts % 60) ;
    ap = (uint16)(val % 10000);
    char []hss= {'N','S','E','W'};
    return "%04d%04d %c".printf(bp, ap, hss[ind]);
}

void display_data(FrID id, uint val)
{
    double r;

    switch(id)
    {
        case FrID.ACCX_ID:
        case FrID.ACCY_ID:
        case FrID.ACCZ_ID:
            r = ((int)val) / 100.0;
            stdout.printf("%s %.2f g\n",id.to_string(), r);
            break;
        case FrID.VFAS_ID:
            r = val / 100.0;
            stdout.printf("%s %.1f V\n", id.to_string(), r);
            break;
        case FrID.GPS_LONG_LATI_ID:
            var s = parse_lat_lon (val);
            stdout.printf("%s %s\n", id.to_string(), s);
            break;
        case FrID.GPS_ALT_ID:
            r =((int)val) / 100.0;
            stdout.printf("%s %.1f m", id.to_string(), r);
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
        case FrID.VARIO_ID:
        case FrID.CURR_ID:
        case FrID.CELLS_ID:
        case FrID.T1_ID:
        case FrID.T2_ID:
        case FrID.RPM_ID:
        case FrID.FUEL_ID:
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
            stdout.printf("Unhandled %s, raw value %u\n", id.to_string(), val);
            break;
        case FrID.RSSI_ID:
            stdout.printf("%s %u dB\n", id.to_string(), (val & 0xff));
            break;
        case FrID.XJT_VERSION_ID:
            stdout.printf("%s %x.%x\n", id.to_string(),
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

bool check_buffer(uint8[] buf)
{
    bool res = fr_checksum(buf);
    if(res)
    {
        FrID id;
        uint val;
            /* fixme serialisation */
        id = (FrID)(*(ushort*)(buf+3));
        val = *(uint*)(buf+5);
        display_data(id,val);
    }
    return res;
}

public static int main (string? []args)
{
    uint good = 0;
    uint bad = 0;
    uint nshort = 0;

    try
    {
        var file = File.new_for_commandline_arg (args[1]);
        var file_stream = file.read ();
        var dis= new DataInputStream (file_stream);
        dis.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);
        uint8 buf[256];
        bool stuffed = false;
        uint8 nb = 0;

        while (true)
        {
            uint8 b = dis.read_byte ();
            if (b == FrProto.P_START)
            {
                if (nb == FrProto.P_SIZE)
                {
                    var res = check_buffer(buf);
                    if (res)
                        good++;
                    else
                        bad++;
                }
                else
                {
                    nshort++;
                }
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
        }
    }
    catch
    {
    }
    stdout.printf("total %u, good %u, bad %u, short %u\n", (good+bad+nshort),
                  good,bad,nshort);
    return 0;
}
