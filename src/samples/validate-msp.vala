/*
 * Simple MSP validator
 * Expects a line of hex 'bytes' on stdin (with leading 0x).


$ ./validate-msp
0x24 0x58 0x3e 0xa5 0x42 0x42 0x12 0x00 0x48 0x65 0x6c 0x6c 0x6f 0x20 0x66 0x6c 0x79 0x69 0x6e 0x67 0x20 0x77 0x6f 0x72 0x6c 0x64 0x82
MSPV2 Dumping 27 bytes
0x24 0x58 0x3e 0xa5 0x42 0x42 0x12 0x00 0x48 0x65 0x6c 0x6c 0x6f 0x20 0x66 0x6c 0x79 0x69 0x6e 0x67 0x20 0x77 0x6f 0x72 0x6c 0x64 0x82
Checksum validates
*/

class MSPValidator :Object
{
    private uint8[] txbuf;
    private uint8 writedirn;

    public MSPValidator() {
        txbuf = new uint8[4096];
    }

    public void set_direction(uint8 c) {
        writedirn = c;
    }

    private uint8 crc8_dvb_s2(uint8 crc, uint8 a) {
        crc ^= a;
        for (int i = 0; i < 8; i++) {
            if ((crc & 0x80) != 0)
                crc = (crc << 1) ^ 0xd5;
            else
                crc = crc << 1;
        }
        return crc;
    }

    private uint8 * serialise_u16(uint8* rp, uint16 v) {
        *rp++ = v & 0xff;
        *rp++ = v >> 8;
        return rp;
    }

    public uint8* deserialise_u16(uint8* rp, out uint16 v) {
        v = *rp | (*(rp+1) << 8);
        return rp + sizeof(uint16);
    }

    private size_t generate_v1(uint8 cmd, void *data, size_t len) {
        uint8 ck = 0;
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

    public size_t generate_v2(uint16 cmd, void *data, size_t len, uint8 flags=0) {
        uint8 ck2=0;
        uint8* ptx = txbuf;
        uint8* pdata = data;

        *ptx++ ='$';
        *ptx++ ='X';
        *ptx++ = writedirn;
        *ptx++ = flags;
        ptx = serialise_u16(ptx, cmd);
        ptx = serialise_u16(ptx, (uint16)len);
        ck2 = crc8_dvb_s2(ck2, txbuf[3]);
        ck2 = crc8_dvb_s2(ck2, txbuf[4]);
        ck2 = crc8_dvb_s2(ck2, txbuf[5]);
        ck2 = crc8_dvb_s2(ck2, txbuf[6]);
        ck2 = crc8_dvb_s2(ck2, txbuf[7]);

        for (var i = 0; i < len; i++) {
            *ptx = *pdata++;
            ck2 = crc8_dvb_s2(ck2, *ptx);
            ptx++;
        }
        *ptx = ck2;
        return len+9;
    }

    public bool validate(uint8[]mbuf, uint n) {
//        dump_raw_data(mbuf, n);
        if(mbuf[0] == '$') {
            if(mbuf[1] == 'M')
                print("MSPv1 ");
            else if (mbuf[1] == 'X')
                print("MSPV2 ");
            else {
                print("Invalid message indicator\n");
                return false;
            }
            if(mbuf[2] == '>' || mbuf[2] == '<') {
                size_t len;
                uint16 cmd;
                set_direction(mbuf[2]);
                if(mbuf[1] == 'M') {
                    len = mbuf[3];
                    cmd = mbuf[4];
                    if (n != len + 6) {
                        print("Invalid data size %lu %lu\n", len, n);
                        return false;
                    }
                    else {
                        var ll = generate_v1((uint8)cmd, &mbuf[5], len);
                        dump_raw_data(txbuf, (uint)ll);
                        if(txbuf[ll-1] == mbuf[n-1]) {
                            print("Checksum validates\n");
                            return true;
                        }
                        else {
                            print("Checksum validation fails %x %x\n",
                                  txbuf[ll-1], mbuf[n-1]);
                            return false;
                        }
                    }
                } else {
                    deserialise_u16(&mbuf[4], out cmd);
                    deserialise_u16(&mbuf[6], out len);
                    if (n != len + 9) {
                        print("Invalid data size %lu %lu\n", len, n);
                        return false;
                    } else {
                        var ll = generate_v2(cmd, &mbuf[8], len, mbuf[3]);
                        dump_raw_data(txbuf, (uint)ll);
                        if(txbuf[ll-1] == mbuf[n-1])
                        {
                            print("Checksum validates\n");
                            return true;
                        } else {
                            print("Checksum validation fails %x %x\n",
                                  txbuf[ll-1], mbuf[n-1]);
                            return false;
                        }
                    }
                }
            } else {
                print("Invalid / error message direction\n");
                return false;
            }
        } else {
            print("Invalid start byte %x %u\n", mbuf[0], mbuf[0]);
            return false;
        }
    }

    private void dump_raw_data (uint8[]buf, uint len) {
        stderr.printf("Dumping %u bytes\n", len);
        for(var nc = 0; nc < len; nc++) {
            stderr.printf("0x%02x ", buf[nc]);
        }
        stderr.printf("\n");
    }
}

static int main (string[] args) {
    var m = new MSPValidator();
    var buffer = new char[4096];
    var mbuf = new uint8[2048];
    while (!stdin.eof ()) {
        string chunk = stdin.gets (buffer);
        var parts = chunk.chomp().split(" ");
        uint n = 0;
        foreach( var p in parts) {
            var l = long.parse(p);
            mbuf[n] = (uint8)l;
            n++;
        }
        if(n > 6) {
            m.validate(mbuf, n);
        } else {
            print("Buffer is too small %u\n", n);
        }
    }
    return 0;
}
