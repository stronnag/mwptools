
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
extern unowned string get_error_text(int err, uint8[] buf, size_t len);

public class MWSerial : Object
{
    const int MAX_INIT_ERR = 16;
    const int YAW_OFFSET  = 41;
    const int SERVO_SIZE = 56;

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
        CALIBRATE_ACC=205,
        CALIBRATE_MAG=206
    }

    public int fd {private set; get;}
    public  bool available {private set; get;}
    protected int prof0;
    protected int prof1;
    private uint8 typ;
    private int pfd;
    private string defprof;
    private int raws = -1;
    private static int rxerr = 0;

    public static string devname;
    protected static string defname;
    protected static int brate;
    protected static int lwait = 5;
    private static string profiles;
    protected static bool presave;
    protected static bool merge = false;
    protected static bool amerge = false;
    protected static bool logmsp;
    protected static bool noreboot = false;
    protected static bool calacc = false;
    protected static bool calmag = false;
    protected static bool setall = false;
    protected static bool keep_parts = false;
    protected static bool verbose = false;

    const OptionEntry[] options = {
        { "device", 'd', 0, OptionArg.STRING, out devname, "device name", null},
        { "output-file", 'o', 0, OptionArg.STRING, out defname, "output file name", null},
        { "baudrate", 'b', 0, OptionArg.INT, out brate, "Baud rate", null},
        { "line-delay", 0, 0, OptionArg.INT, out lwait, "(ms)", null},
        { "profiles", 'p', 0, OptionArg.STRING, out profiles, "Profile (0-2)", null},
        { "presave", 'i', 0, OptionArg.NONE, out presave, "Save before setting", null},
        { "logmsp", 'l', 0, OptionArg.NONE, out logmsp, "Log MSP", null},
        { "verbose", 'v', 0, OptionArg.NONE, out verbose, "Echo messages", null},
        { "acc", 0, 0, OptionArg.NONE, out calacc, "cal acc", null},
        { "all", 'A', 0, OptionArg.NONE, out setall, "All", null},
        { "mag", 0, 0, OptionArg.NONE, out calmag, "cal mag", null},
        { "keep-parts", 'k', 0, OptionArg.NONE, out keep_parts, "Keep parts after merge", null},
        { "noreboot", 'R', 0, OptionArg.NONE, out noreboot, "No Reboot", null},
        { "merge-profiles", 'm', 0, OptionArg.NONE, out merge, "Generate a merged file for multiple profiles", null},
        { "merge-auxp", 'a', 0, OptionArg.NONE, out amerge, "Generate a merged file for multiple profiles with common aux settings", null},
        {null}
    };

    public MWSerial()
    {
        available = false;
        fd = -1;
        if(brate == 0)
            brate = 115200;
    }

    public void set_iofd(int _pfd = 2)
    {
        pfd = _pfd;
    }

    public bool open()
    {
        if(logmsp)
        {
            var dt = new DateTime.now_local();
            var fn  = "msp_%s.log".printf(dt.format("%F_%H%M%S"));
            raws = Posix.open (fn, Posix.O_TRUNC|Posix.O_CREAT|Posix.O_WRONLY, 0640);
        }
        available = false;
        fd = open_serial(devname, brate);
        if(fd < 0)
        {
            int lasterr = Posix.errno;
            string s;
            uint8 ebuf[256];

            var es = get_error_text(lasterr, ebuf, 256);
            if(es == null || ebuf[0] == 0)
                s="failed, reason unknown";
            else
                s = es;
            message("open %s - %s\n", devname, es);
            fd = -1;
        }
        else
        {
            available = true;
        }
        return available;
    }


    private void closelog()
    {
        if(raws != -1)
        {
            Posix.close(raws);
            raws = -1;
        }
    }

    ~MWSerial()
    {
        closelog();
        if(fd != -1)
            close();
    }

    public void close()
    {
        closelog();

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
            else if (res == 1)
            {
                if(logmsp)
                {
                    Posix.write(raws, &c,1);
                }

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
                            message(" CRC Fail, got %d != %d (%d)\n", c,checksum,cmd);
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

    private ResCode read_line(out uint8 [] buf, out int len, bool wait=false)
    {
        ResCode rescode = ResCode.OK;
        len = 0;
        uint8 c = 0;
        int nto = 0;
        buf = new uint8[256];
        int xnto = 10;

        buf[0] = 0;

        for(var done = false ; ; )
        {
            var res = Posix.read(fd,&c,1);
            if (res == 0)
            {
                if (done && wait)
                    break;

                nto++;
                if (nto >= xnto)
                {
                    done = true;
                    rescode = ResCode.TIMEOUT;
                    break;
                }
            }
            else
            {
                nto = 0;
                xnto = 1;
                if((c == '#' && done) || c == '\r')
                    continue;

                {
                    if (len < 256)
                        buf[len++] = c;
                    else
                    {
                        rescode = ResCode.ERR;
                        done = true;
                        break;
                    }
                    if (c == '\n')
                    {
                        done = true;
                        if(wait == false)
                            break;
                    }
                }
            }
        }
        return rescode;
    }

    private void drain(out uint8 [] buf, int limit)
    {
        uint8 c = 0;
        int nc = 0;
        int len = 0;
        buf = new uint8[4096];

        while (true)
        {
            var res =  Posix.read(fd,&c,1);
            if (res == 1)
            {
                buf[len] =c;
                len++;
            }
            else
            {
                nc++;
                if (nc >= limit)
                    break;
            }
        }
        buf[len] = 0;
        if(len == 0)
        {
            message(" **** no data received\n ****");
            rxerr++;
            if(rxerr == 5)
            {
                message("Likely your restore is broken\n");
                Posix.exit(255);
            }
        }
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
            if(logmsp)
            {
                Posix.write(raws, dstr, len);
            }
        }
    }

    public ssize_t write(void *buf, size_t count = -1)
    {
        if(count == -1)
            count = ((string)buf).length;
        return Posix.write(fd, buf, count);
    }


    private string build_part_name(string ifn, string q, string p)
    {
        var dirname = Path.get_dirname(defname);
        var filename =  Path.get_basename(defname);
        var parts = filename.split(".");
        var idx = parts.length - 2;
        if (idx < 0) idx = 0;
        parts[idx] = "%s%s_%s%s".printf(ifn,parts[idx],q,p);
        filename = string.joinv(".",parts);
        return Path.build_filename(dirname, filename);
    }

    public void dump_settings(string ifn="")
    {
        uint8 [] line;
        int len;
        for(var p = prof0; p <= prof1; p++)
        {
            FileStream os;
            int nbytes = 0;
            string fn=null;
            if(defname != "-")
            {
                if(prof0 != prof1)
                {
                    fn = build_part_name(ifn,"p",p.to_string());
                }
                else
                {
                    fn = "%s%s".printf(ifn,defname);
                }
                message("Saving to %s\n",fn);
                os = FileStream.open(fn, "w");
            }
            else
            {
                os = FileStream.fdopen(1, "w");
            }

            if (os == null)
            {
                var s = Posix.strerror(Posix.errno);
                message("Unable to open %s (%s), no backup created\n", fn,s);
                return;
            }

            var dt = new DateTime.now_local();
            os.printf("# mwptools / cf-cli dump %s\n", dt.format("%FT%T%z"));
            os.puts("# cf-cli is a tool to manage Cleanflight CLI dump backup and restore\n");
            os.puts("# <https://github.com/stronnag/mwptools>\n");
            os.puts("# Windows binary <http://www.daria.co.uk/cf-cli/>\n#\n");

            string cmd = "profile %d\n".printf(p);
            write(cmd.data);
            while(read_line(out line, out len) == ResCode.OK)
                ;
            write("dump\n");
            while(read_line(out line, out len) == ResCode.OK)
            {
                nbytes += line.length;
                if ((string)line != "dump\n")
                {
                    if(((string)line).contains("Cleanflight"))
                    {
                        os.puts("# ");
                    }
                    os.printf("%s", (string)line);
                }
            }
            if(defprof != null)
            {
                os.printf("## defprof=%s\n", defprof);
            }
            os.flush();
            os=null;
            if(nbytes < 4096)
            {
                message("Read too few bytes (%d)\nNo backup created\n", nbytes);
                if(fn != null)
                    Posix.unlink(fn);
            }
        }
    }

    public void merge_file ()
    {
        if(defname != "-" && (prof0 != prof1))
        {
            string line;
            string [] aux = null;
            int auxno = 0;
            var ofn = build_part_name("","merged","");
            FileStream out =  FileStream.open(ofn, "w");
            if(out == null)
            {
                var s = Posix.strerror(Posix.errno);
                message("Unable to open %s (%s), no backup created\n", ofn,s);
                return;
            }
            string dprof = null; // only want once

            for(var p = prof0; p <= prof1; p++)
            {
                FileStream fp;
                var fn = build_part_name("","p",p.to_string());
                fp = FileStream.open(fn, "r");
                if(fp != null)
                {
                    message("Merging %s\n",fn);
                    bool skip = true;
                    int na = 0;

                    while((line = fp.read_line ()) != null)
                    {
                        if(line.contains("## defprof="))
                        {
                            dprof = line;
                            continue;
                        }
                        if(p == prof0)
                        {
                            if(amerge && line.has_prefix("aux "))
                            {
                                aux += line;
                                auxno++;
                            }
                            out.printf("%s\n", line);
                        }
                        else
                        {
                            if(line.has_prefix("# dump profile"))
                                skip = false;

                            if(skip == false)
                            {
                                if(amerge && line.has_prefix("aux "))
                                {
                                    if (na < auxno)
                                    {
                                        line = aux[na];
                                        na++;
                                    }
                                    else
                                        message("Unbalanced aux lines\n");
                                }
                                out.printf("%s\n", line);
                            }
                        }
                    }
                    if(!keep_parts)
                        Posix.unlink(fn);
                }
                else
                {
                    message("Failed to open %s, merge aborted\n", fn);
                    out = null;
                    Posix.unlink(ofn);
                    break;
                }
            }
            if(dprof != null)
            {
                out.printf("%s\n", dprof);
            }
            out.flush();
        }
        else
            message("No merge performed\n");
    }

    private void set_line(string line)
    {
        uint8 []rdata;

        write(line);
        write("\n");
        var to = 1;
        if (line.has_prefix("aux "))
            to = 2;
        if (line.has_prefix("serial "))
            to = 2;
        if (line.has_prefix("profile "))
        {
            to = 20;
            Thread.usleep(1000*1000);
        }
        if (line.has_prefix("smix reverse"))
            to = 10;
        if (line.has_prefix("save"))
            to = 50;
        Thread.usleep(lwait*1000);
        drain(out rdata, to);
        Thread.usleep(lwait*1000);
        if(verbose)
            stdout.printf("%s", (string)rdata);
    }

    public void replay_file(string fn)
    {
        var fp = FileStream.open(fn, "r");
        string rline;
        uint8 []spinchar = {'|','/', '-', '\\','*'};
        uint spindex=0;

        message("Replaying %s\n", fn);
        while((rline = fp.read_line ()) != null)
        {
            var line = rline.strip();
            if(line.length > 0 && line[0] != '#')
            {
                set_line(line);
                if(verbose == false || !Posix.isatty(1))
                {
                    message("[%c]  \r", spinchar[spindex]);
                    spindex++;
                    spindex %= 5;
                }
            }
            else
            {
                if(line.contains("## defprof="))
                {
                    var parts = line.split("=");
                    if(parts.length == 2)
                    {
                        defprof = parts[1];
                    }
                }
            }
        }
        if(!verbose)
            stderr.printf("\r");
        if(defprof != null)
        {
            message("Setting %s\n", defprof);
            set_line("%s\n".printf(defprof));
        }
        fp = null;
    }

    public int init_app(string[] args, ref string? rfile)
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

        prof0 = 0;
        prof1 = 0;

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

        if(setall)
        {
            prof0 = 0;
            prof1 = 2;
            amerge = true;
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
        if(args.length == 2)
            rfile = args[1];

        return 0;
    }

    public int fc_init()
    {
        ResCode res = 0;
        typ = 0;

        uint8 [] line;
        int len;

        write("#");
        while((res = read_line(out line, out len)) == ResCode.OK)
            ;
        return 0;
    }

    public void perform_backup()
    {
        ResCode res = 0;
        uint8 [] line;
        int len;

        write("profile\n");
        while(read_line(out line, out len) == ResCode.OK)
        {
            if(len >= 9)
                defprof = (string)line;
        }

        dump_settings();
        write("%s\n".printf(defprof));
        while(read_line(out line, out len) == ResCode.OK)
            ;

        write("exit\n");
        while((res = read_line(out line, out len)) == ResCode.OK)
            ;

        if(merge || amerge)
        {
            merge_file();
        }
    }

    public bool try_open(bool docals=false)
    {
        int ocount = 30;
        do
        {
            open();
            if(!available)
            {
                Thread.usleep(1000000);
                ocount--;
            }
        } while(!available && ocount != 0);
        if(available)
        {
            ResCode res = 0;
            uint8 cmd;
            uint8 [] raw;
            do
            {
                send_msp(Cmds.IDENT, null, 0);
                res =  read_msp(out cmd, out raw);
            } while (res != ResCode.OK);
            message("Ready ...\n");
            if(docals)
            {
                if(calmag)
                {
                    message("Magnetometer calibration started\n");
                    do
                    {
                        send_msp(Cmds.CALIBRATE_MAG, null, 0);
                        res =  read_msp(out cmd, out raw);
                    } while (res != ResCode.OK);
                    Thread.usleep(30*1000*1000);
                    message("Magnetometer calibration finished\n");
                    close();
                    Posix.exit(0);
                }
                if(calacc)
                {
                    message("Accelerometer calibration started\n");
                    do
                    {
                        send_msp(Cmds.CALIBRATE_ACC, null, 0);
                        res =  read_msp(out cmd, out raw);
                    } while (res != ResCode.OK);
                    Thread.usleep(2*1000*1000);
                    message("Accelerometer calibration finished\n");
                }
            }
        }
        return available;
    }

    public void perform_restore(string restore_file)
    {
        ResCode res = 0;
        uint8 [] line;
        int len;

        if(presave)
            dump_settings("__");

        if(noreboot == false)
        {
            write("defaults\n");
            while((res = read_line(out line, out len)) == ResCode.OK)
                ;
            close();
            message("Reboot on defaults\n");
            Thread.usleep(1000000);

            try_open(true);

            write("#");
            while((res = read_line(out line, out len)) == ResCode.OK)
                ;
        }
        replay_file(restore_file);
        set_line("save");
        message("Reboot on save\n");
        close();
    }

    public void message(string format, ...)
    {
        var v = va_list();
        var now = new DateTime.now_local ();
        string ds = now.format ("%T");
        var sb = new StringBuilder();
        sb.append(ds);
        sb.append(" ");
        sb.append(format.vprintf(v));
        Posix.write(pfd, sb.str, sb.str.length);
    }
}
