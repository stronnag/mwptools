
// valac --pkg gio-2.0 frsky.vala

enum FrID {
    AccX_DATA_ID =  0x0700,
    AccY_DATA_ID = 0x0710,
    AccZ_DATA_ID = 0x0720,
    ASS_SPEED_DATA_ID = 0x0A00,
    FAS_CURR_DATA_ID = 0x0200,
    FAS_VOLT_DATA_ID = 0x0210,
    FLVSS_CELL_DATA_ID = 0x0300,
    FUEL_DATA_ID = 0x0600,
    GPS_LAT_LON_DATA_ID = 0x0800,
    GPS_ALT_DATA_ID =  0x0820,
    GPS_SPEED_DATA_ID = 0x0830,
    GPS_COG_DATA_ID = 0x0840,
    GPS_HDOP_DATA_ID = 0xF103,
    RPM_T1_DATA_ID = 0x0400,
    RPM_T2_DATA_ID = 0x0410,
    RPM_ROT_DATA_ID = 0x0500,
    SP2UARTB_ADC3_DATA_ID = 0x0900,
    SP2UARTB_ADC4_DATA_ID = 0x0910,
    VARIO_ALT_DATA_ID = 0x0100,
    VARIO_VSI_DATA_ID = 0x0110,
    SP_RSSI = 0xf101,
    SP_BAT = 0xf104,
    SP_SWR = 0xf105,
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
        case FrID.AccX_DATA_ID:
        case FrID.AccY_DATA_ID:
        case FrID.AccZ_DATA_ID:
            r = ((int)val) / 100.0;
            stdout.printf("%s %.2f g\n",id.to_string(), r);            
            break;
        case FrID.FAS_VOLT_DATA_ID:
            r = val / 100.0;
            stdout.printf("%s %.1f V\n", id.to_string(), r);
            break;
        case FrID.GPS_LAT_LON_DATA_ID:
            var s = parse_lat_lon (val);
            stdout.printf("%s %s\n", id.to_string(), s);
            break;
        case FrID.GPS_ALT_DATA_ID:
            r =((int)val) / 100.0;
            stdout.printf("%s %.1f m", id.to_string(), r);
            break;
        case FrID.GPS_SPEED_DATA_ID:
            r = ((val/1000.0)*0.51444444);
            stdout.printf("%s %.2f m/s\n", id.to_string(), r);
            break;
        case FrID.GPS_COG_DATA_ID:
            r = val / 100.0;
            stdout.printf("%s %.1f°\n", id.to_string(), r); 
            break;
        case FrID.GPS_HDOP_DATA_ID:
            r = val / 100.0; // /10.0 ????
            stdout.printf("%s %.1f\n", id.to_string(), r); 
            break;

        case FrID.VARIO_ALT_DATA_ID:
            r = val / 100.0; // /10.0 ????
            stdout.printf("%s %.2f m/s\n", id.to_string(), r); 
            break;
                       
        case FrID.ASS_SPEED_DATA_ID:
        case FrID.FAS_CURR_DATA_ID:
        case FrID.FLVSS_CELL_DATA_ID:
        case FrID.FUEL_DATA_ID:
        case FrID.RPM_T1_DATA_ID:
        case FrID.RPM_T2_DATA_ID:
        case FrID.RPM_ROT_DATA_ID:
        case FrID.SP2UARTB_ADC3_DATA_ID:
        case FrID.SP2UARTB_ADC4_DATA_ID:
        case FrID.VARIO_VSI_DATA_ID:
        case FrID.SP_RSSI:
        case FrID.SP_BAT:
        case FrID.SP_SWR:
        stdout.printf("Unhandled %s, value %u\n", id.to_string(), val);
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
