
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


/* Upload a cleanflight CLI dump back into a naze32 FC */

extern int open_serial(string dev, int baudrate);
extern void close_serial(int fd);

public class MWSerial : Object
{
    const int MAX_INIT_ERR = 16;
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
        S_ERROR
    }

    public enum ResCode
    {
        TIMEOUT=-1,
        OK = 0,
        ERR = 1
    }

    public enum Cmds
    {
        IDENT=100,
        SERVO_CONF=120,
        SET_SERVO_CONF=212,
        EEPROM_WRITE=250
    }

    public int fd {private set; get;}
    public  bool available {private set; get;}

    private static string devname;
    private static string defname;
    private static int brate;
    private static string profiles;
    private static bool presave;
    private static bool tyaw = false;

    const OptionEntry[] options = {
        { "device", 'd', 0, OptionArg.STRING, out devname, "device name", null},
        { "output-file", 'o', 0, OptionArg.STRING, out defname, "output file name", null},
        { "baudrate", 'b', 0, OptionArg.INT, out brate, "Baud rate", null},
        { "profiles", 'p', 0, OptionArg.STRING, out profiles, "Profile (0-2)", null},
        { "presave", 'i', 0, OptionArg.NONE, out presave, "Save before setting", null},
        { "force-tri-rev-yaw", 'y', 0, OptionArg.NONE, out tyaw, "Force tri reversed yaw", null},
        {null}
    };

    public MWSerial()
    {
        available = false;
        fd = -1;
        if(devname == null)
            devname = "/dev/ttyUSB0";
        if(brate == 0)
            brate = 115200;
    }

    public bool open()
    {
        fd = open_serial(devname, brate);
        if(fd < 0)
        {
            var lasterr=Posix.errno;
            var s = Posix.strerror(lasterr);
            MWPLog.message("open %s - %s (%d)\n", devname, s, lasterr);
            fd = -1;
            available = false;
        }
        else
        {
            available = true;
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
            close_serial(fd);
            fd = -1;
        }
    }

    private uint8 cksum(uint8[] dstr, size_t len, uint8 init=0)
    {
        var cs = init;
        for(int n = 0; n < len; n++)
        {
            cs ^= dstr[n];
        }
        return cs;
    }

    private ResCode read_msp(out Cmds cmd, out uint8 [] raw)
    {
        int nto = 0;
        uint8 c = 0;
        uint8 checksum = 0;
        uint8 csize = 0;
        uint8 needed = 0;
        int rawp = 0;
        States state = States.S_HEADER;
        int errcnt = 0;
        ssize_t res;
        bool err = false;
        bool errstate = false;
        ResCode rescode = ResCode.OK;

        raw = null;
        cmd = 0;

        for(var done = false ; !done;)
        {
            res = Posix.read(fd,&c,1);
            if (res == 0)
            {
                nto++;
                if (nto == 10)
                {
                    rescode = ResCode.TIMEOUT;
                    done = true;
                }
            }
            else
            {
                nto = 0;
                switch(state)
                {
                    case States.S_ERROR:
                        if (c == '$')
                        {
                            state=States.S_HEADER1;
                            errstate = false;
                            errcnt = 0;
                        }
                        else
                        {
                            errcnt++;
                            if (errcnt == 10)
                            {
                                done = true;
                                rescode = ResCode.ERR;
                            }
                        }
                        break;

                    case States.S_HEADER:
                        if (c == '$')
                        {
                            state=States.S_HEADER1;
                            errstate = false;
                        }
                        else
                        {
//                            MWPLog.message(" fail on header %x\n", c);
                            state=States.S_ERROR;
                        }
                        break;
                    case States.S_HEADER1:
                        if(c == 'M')
                        {
                            state=States.S_HEADER2;
                        }
                        else
                        {
//                            MWPLog.message(" fail on header1 %x\n", c);
                            state=States.S_ERROR;
                        }
                        break;
                    case States.S_HEADER2:
                        if(c == '>' || c == '!')
                        {
                            err = (c == '!');
                            state = States.S_SIZE;
                        }
                        else
                        {
//                            MWPLog.message(" fail on header2 %x\n", c);
                            state=States.S_ERROR;
                        }
                        break;

                    case States.S_SIZE:
                        checksum = csize = needed = c;
                        if(needed > 0)
                        {
                            raw = new uint8[csize];
                            rawp= 0;
                        }
                        state = States.S_CMD;
                        break;
                    case States.S_CMD:
                        cmd = (Cmds)c;
                        checksum ^= c;
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
                        raw[rawp++] = c;
                        needed--;
                        if(needed == 0)
                        {
                            checksum = cksum(raw, csize, checksum);
                            state = States.S_CHECKSUM;
                        }
                        break;
                    case States.S_CHECKSUM:
                        if(checksum  == c)
                        {
                            done = true;
                        }
                        else
                        {
                            MWPLog.message(" CRC Fail, got %d != %d (%d)\n",
                                           c,checksum,cmd);
                            state = States.S_ERROR;
                        }
                        break;
                    case States.S_END:
                        break;
                }
            }
        }
        return rescode;
    }

    private ResCode read_line(out uint8 [] buf, out int len)
    {
        ResCode rescode = ResCode.OK;
        len = 0;
        uint8 c = 0;
        int nto = 0;
        buf = new uint8[256];
        int xnto = 10;

        buf[0] = 0;

        for(var done = false ; !done;)
        {
            var res = Posix.read(fd,&c,1);
            if (res == 0)
            {
                nto++;
                if (nto >= xnto)
                {
                    done = true;
                    rescode = ResCode.TIMEOUT;
                }
            }
            else
            {
                nto = 0;
                xnto = 1;

                if (c == '\n')
                    done = true;
                else if (c == '\r')
                    ;
                else
                {
                    if (len < 256)
                        buf[len++] = c;
                    else
                    {
                        rescode = ResCode.ERR;
                        done = true;
                    }
                }
            }
        }
        return rescode;
    }

    public void send_msp (Cmds cmd, void *data, size_t len)
    {
        if(available == true)
        {
            var dsize = (uint8)len;
            uint8 dstr[128];
            dstr[0]='$';
            dstr[1]='M';
            dstr[2]= '<';
            dstr[3] = dsize;
            dstr[4] = cmd;
            if (data != null && dsize > 0)
                Posix.memcpy(&dstr[5], data, len);
            len += 3;
            var ck = cksum(dstr[3:len], len, 0);
            dstr[len+2] = ck;
            len += 3;
            Posix.write(fd, dstr, len);
        }
    }

    public ssize_t write(void *buf, size_t count = -1)
    {
        if(count == -1)
            count = ((string)buf).length;
        return Posix.write(fd, buf, count);
    }


    private string build_part_name(string ifn, int p)
    {
        var dirname = Path.get_dirname(defname);
        var filename =  Path.get_basename(defname);
        var parts = filename.split(".");
        var idx = parts.length - 2;
        parts[idx] = "%s%s_p%d".printf(ifn,parts[idx],p);
        filename = string.joinv(".",parts);
        return Path.build_filename(dirname, filename);
    }

    public void dump_settings(int prof0, int prof1, string ifn="")
    {
        uint8 [] line;
        int len;
        FileStream os;

        for(var p = prof0; p <= prof1; p++)
        {
            string fn;
            if(defname != "-")
            {
                if(prof0 != prof1)
                {
                    fn = build_part_name(ifn,p);
                }
                else
                {
                    fn = "%s%s".printf(ifn,defname);
                }
                MWPLog.message("Saving to %s\n",fn);
                os = FileStream.open(fn, "w");
            }
            else
            {
                os = FileStream.fdopen(1, "w");
            }

            var dt = new DateTime.now_local();
            os.printf("# mwptools / cf-cli dump %s\n", dt.format("%FT%T%z"));

            string cmd = "profile %d\n".printf(p);
            write(cmd.data);
            while(read_line(out line, out len) == ResCode.OK)
                ;
            write("dump\n");
            while(read_line(out line, out len) == ResCode.OK)
            {
                if ((string)line != "dump")
                {
                    if(((string)line).contains("Cleanflight"))
                    {
                        os.puts("# ");
                    }
                    os.printf("%s\n", (string)line);
                }
            }
            if(tyaw)
            {
                os.puts("## rev-tri-yaw\n");
            }
            os=null;
        }
    }

    public void replay_file(string fn)
    {
        var fp = FileStream.open(fn, "r");
        string rline;
        int len;

        MWPLog.message("Replaying %s\n", fn);
        while((rline = fp.read_line ()) != null)
        {
            var line = rline.strip();
            if(line.length > 0 && line[0] != '#')
            {
                write(line);
                write("\n");
                uint8 []rdata;
                read_line(out rdata, out len);
                Thread.usleep(50*1000);
            }
            else
            {
                if(line.contains("## rev-tri-yaw"))
                    tyaw = true;
            }
        }
        fp = null;
    }

    public static int main (string[] args)
    {
        try {
            var opt = new OptionContext("cleanflight_dump_file");
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

        int prof0 = 0;
        int prof1 = 0;

        if(profiles != null)
        {
            var parts = profiles.split("-");
            switch(parts.length)
            {
                case 1:
                    prof0 = prof1 = int.parse(parts[0]);
                    break;
                case 2:
                    prof0 = int.parse(parts[0]);
                    prof1 = int.parse(parts[1]);
                    break;
            }
            if(prof0 < 0 || prof0 > 2)
                prof0 = 0;

            if(prof1 < prof0)
                prof1 = prof0;

            if(prof1 > 2)
                prof1 = 2;
        }

        if(defname == null)
        {
            var dt = new DateTime.now_local();
            defname = "cf_cli-%s.txt".printf(dt.format("%F_%H%M%S"));
        }

        if(args.length > 1)
        {
            if (Posix.access(args[1],Posix.R_OK) != 0)
            {
                stderr.printf ("File '%s' doesn't exist.\n", args[1]);
                return 255;
            }
            if (args[1] == defname)
            {
                stderr.puts ("Can't save and restore to same file\n");
                return 255;
            }
        }
        uint8 cmd;
        uint8 [] raw;
        var s = new MWSerial();

        if(s.open())
        {
            ResCode res = 0;
            int errcnt = 0;
            uint8 typ = 0;

            do
            {
                s.send_msp(Cmds.IDENT, null, 0);
                res =  s.read_msp(out cmd, out raw);
                if(res != ResCode.OK)
                {
                    stderr.printf("Failed %s\n", res.to_string());
                    errcnt++;
                    if(errcnt == MAX_INIT_ERR)
                    {
                        stderr.printf("Giving up after %d attempts\n", errcnt);
                        return 0;
                    }
                }
                else
                    typ = raw[1];

            } while (res != ResCode.OK);

            if(typ == 1 && tyaw == false)
            {
                s.send_msp(Cmds.SERVO_CONF,null,0);
                if(s.read_msp(out cmd, out raw) == ResCode.OK)
                {
                    tyaw = ((raw[41] & 1) == 1);
                    if(tyaw)
                        MWPLog.message("Discovered Tri Yaw\n");
                }
            }

            uint8 [] line;
            int len;

            s.write("#");
            while((res = s.read_line(out line, out len)) == ResCode.OK)
                ;

            if(args.length == 1)
            {
                s.dump_settings(prof0, prof1);
                s.write("exit\n");
                while((res = s.read_line(out line, out len)) == ResCode.OK)
                    ;
            }
            else
            {
                if(presave)
                    s.dump_settings(prof0, prof1,"__");

                s.write("defaults\n");
                while((res = s.read_line(out line, out len)) == ResCode.OK)
                    ;

                Thread.usleep(1000000);
                MWPLog.message("Reboot on defaults\n");
                do
                {
                    s.send_msp(Cmds.IDENT, null, 0);
                    res =  s.read_msp(out cmd, out raw);
                } while (res != ResCode.OK);
                MWPLog.message("Rebooted ...\n");
                s.write("#");
                while((res = s.read_line(out line, out len)) == ResCode.OK)
                    ;
                s.replay_file(args[1]);
                s.write("save\n");
                while((res = s.read_line(out line, out len)) == ResCode.OK)
                    ;

                MWPLog.message("Reboot on save\n");
                Thread.usleep(1000000);

                do
                {
                    s.send_msp(Cmds.IDENT, null, 0);
                    res =  s.read_msp(out cmd, out raw);
                    if(res == ResCode.OK)
                        typ = raw[1];

                } while (res != ResCode.OK);
                if(tyaw)
                {
                    if(typ == 1)
                    {
                        s.send_msp(Cmds.SERVO_CONF,null,0);
                        if(s.read_msp(out cmd, out raw) == ResCode.OK)
                        {
                            raw[41] |= 1;
                        }
                        s.send_msp(Cmds.SET_SERVO_CONF,raw,raw.length);
                        if(s.read_msp(out cmd, out raw) == ResCode.OK)
                        {
                            MWPLog.message("Set Tri Yaw\n");
                            s.send_msp(Cmds.EEPROM_WRITE,null,0);
                            s.read_msp(out cmd, out raw);
                        }
                    }
                    s.write("#");
                    while((res = s.read_line(out line, out len)) == ResCode.OK)
                        ;
                    s.dump_settings(prof0, prof1);
                    s.write("exit\n");
                    while((res = s.read_line(out line, out len)) == ResCode.OK)
                    ;
                }
            }
        }
        MWPLog.message("Done\n");
        return 0;
    }
}
