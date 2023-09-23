public class Fuzzer : Object {
    private static int baud = 115200;
    private static string dev;
    private static int cmdmax=4095;
    private static int paymax=4095;
    private static uint noevil = 0;
    private static uint loops  = 0;

    const OptionEntry[] options = {
        { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", null},
        { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
        { "cmdmax", 'c', 0, OptionArg.INT, out cmdmax, "maximum comamnd value generated [4095]",null},
        { "paymax", 'p', 0, OptionArg.INT, out paymax, "maximum payload size generated [4095]",null},
        { "evil", 'e', 0, OptionArg.INT, out noevil, "degree of evilness (default=no dangerous commands, 1=no reboot, 2=no reboot or dataflash commands", null},
        { "loops", 'l', 0, OptionArg.INT, out loops, "number of loops (default no limit)",null},
        {null}
    };

    public enum Danger {
        MSP_SET_INAV_PID = 7,
        MSP_SET_NAME = 11,
        MSP_SET_NAV_POSHOLD = 13,
        MSP_SET_CALIBRATION_DATA = 15,
        MSP_SET_POSITION_ESTIMATION_CONFIG = 17,
        MSP_SET_RTH_AND_LAND_CONFIG = 22,
        MSP_SET_FW_CONFIG = 24,
        MSP_SET_MODE_RANGE = 35,
        MSP_SET_FEATURE = 37,
        MSP_SET_BOARD_ALIGNMENT = 39,
        MSP_SET_CURRENT_METER_CONFIG = 41,
        MSP_SET_MIXER = 43,
        MSP_SET_RX_CONFIG = 45,
        MSP_SET_LED_COLORS = 47,
        MSP_SET_LED_STRIP_CONFIG = 49,
        MSP_SET_RSSI_CONFIG = 51,
        MSP_SET_ADJUSTMENT_RANGE = 53,
        MSP_SET_CF_SERIAL_CONFIG = 55,
        MSP_SET_VOLTAGE_METER_CONFIG = 57,
        MSP_SET_PID_CONTROLLER = 60,
        MSP_SET_ARMING_CONFIG = 62,
        MSP_SET_RX_MAP = 65,
        MSP_SET_BF_CONFIG = 67,
        MSP_REBOOT = 68,
        MSP_DATAFLASH_SUMMARY = 70,
        MSP_DATAFLASH_READ = 71,
        MSP_DATAFLASH_ERASE = 72,
        MSP_SET_LOOP_TIME = 74,
        MSP_SET_FAILSAFE_CONFIG = 76,
        MSP_SET_RXFAIL_CONFIG = 78,
        MSP_SET_BLACKBOX_CONFIG = 81,
        MSP_SET_TRANSPONDER_CONFIG = 83,
        MSP_SET_OSD_CONFIG = 85,
        MSP_OSD_CHAR_WRITE = 87,
        MSP_SET_VTX_CONFIG = 89,
        MSP_SET_ADVANCED_CONFIG = 91,
        MSP_SET_FILTER_CONFIG = 93,
        MSP_SET_PID_ADVANCED = 95,
        MSP_SET_SENSOR_CONFIG = 97,
        MSP_SET_SPECIAL_PARAMETERS = 99,
        MSP_SET_OSD_VIDEO_CONFIG = 181,
        MSP_SET_RAW_RC = 200,
        MSP_SET_RAW_GPS = 201,
        MSP_SET_PID = 202,
        MSP_SET_BOX = 203,
        MSP_SET_RC_TUNING = 204,
        MSP_SET_MISC = 207,
        MSP_RESET_CONF = 208,
        MSP_SET_WP = 209,
        MSP_SET_HEAD = 211,
        MSP_SET_SERVO_CONFIGURATION = 212,
        MSP_SET_MOTOR = 214,
        MSP_SET_NAV_CONFIG = 215,
        MSP_SET_3D = 217,
        MSP_SET_RC_DEADBAND = 218,
        MSP_SET_RESET_CURR_PID = 219,
        MSP_SET_SENSOR_ALIGNMENT = 220,
        MSP_SET_LED_STRIP_MODECOLOR = 221,
        MSP_SET_ACC_TRIM = 239,
        MSP_BIND = 240,
        MSP_SET_SERVO_MIX_RULE = 242,
        MSP_SET_4WAY_IF = 245,
        MSP_EEPROM_WRITE = 250
    }
    private const uint16 [] dangerous = {
        Danger.MSP_SET_INAV_PID,
        Danger.MSP_SET_NAME,
        Danger.MSP_SET_NAV_POSHOLD,
        Danger.MSP_SET_CALIBRATION_DATA,
        Danger.MSP_SET_POSITION_ESTIMATION_CONFIG,
        Danger.MSP_SET_RTH_AND_LAND_CONFIG,
        Danger.MSP_SET_FW_CONFIG,
        Danger.MSP_SET_MODE_RANGE,
        Danger.MSP_SET_FEATURE,
        Danger.MSP_SET_BOARD_ALIGNMENT,
        Danger.MSP_SET_CURRENT_METER_CONFIG,
        Danger.MSP_SET_MIXER,
        Danger.MSP_SET_RX_CONFIG,
        Danger.MSP_SET_LED_COLORS,
        Danger.MSP_SET_LED_STRIP_CONFIG,
        Danger.MSP_SET_RSSI_CONFIG,
        Danger.MSP_SET_ADJUSTMENT_RANGE,
        Danger.MSP_SET_CF_SERIAL_CONFIG,
        Danger.MSP_SET_VOLTAGE_METER_CONFIG,
        Danger.MSP_SET_PID_CONTROLLER,
        Danger.MSP_SET_ARMING_CONFIG,
        Danger.MSP_SET_RX_MAP,
        Danger.MSP_SET_BF_CONFIG,
        Danger.MSP_REBOOT,
        Danger.MSP_DATAFLASH_SUMMARY,
        Danger.MSP_DATAFLASH_READ,
        Danger.MSP_DATAFLASH_ERASE,
        Danger.MSP_SET_LOOP_TIME,
        Danger.MSP_SET_FAILSAFE_CONFIG,
        Danger.MSP_SET_RXFAIL_CONFIG,
        Danger.MSP_SET_BLACKBOX_CONFIG,
        Danger.MSP_SET_TRANSPONDER_CONFIG,
        Danger.MSP_SET_OSD_CONFIG,
        Danger.MSP_OSD_CHAR_WRITE,
        Danger.MSP_SET_VTX_CONFIG,
        Danger.MSP_SET_ADVANCED_CONFIG,
        Danger.MSP_SET_FILTER_CONFIG,
        Danger.MSP_SET_PID_ADVANCED,
        Danger.MSP_SET_SENSOR_CONFIG,
        Danger.MSP_SET_SPECIAL_PARAMETERS,
        Danger.MSP_SET_OSD_VIDEO_CONFIG,
        Danger.MSP_SET_RAW_RC,
        Danger.MSP_SET_RAW_GPS,
        Danger.MSP_SET_PID,
        Danger.MSP_SET_BOX,
        Danger.MSP_SET_RC_TUNING,
        Danger.MSP_SET_MISC,
        Danger.MSP_RESET_CONF,
        Danger.MSP_SET_WP,
        Danger.MSP_SET_HEAD,
        Danger.MSP_SET_SERVO_CONFIGURATION,
        Danger.MSP_SET_MOTOR,
        Danger.MSP_SET_NAV_CONFIG,
        Danger.MSP_SET_3D,
        Danger.MSP_SET_RC_DEADBAND,
        Danger.MSP_SET_RESET_CURR_PID,
        Danger.MSP_SET_SENSOR_ALIGNMENT,
        Danger.MSP_SET_LED_STRIP_MODECOLOR,
        Danger.MSP_SET_ACC_TRIM,
        Danger.MSP_BIND,
        Danger.MSP_SET_SERVO_MIX_RULE,
        Danger.MSP_SET_4WAY_IF,
        Danger.MSP_EEPROM_WRITE
    };

    public static bool fquit = false;
    private static MainLoop ml;
    private uint ns = 0;
    private uint nr = 0;
    private MWSerial s;
    Rand rand;
    private uint tid = 0;

    Fuzzer() {
        rand = new Rand();
        ml = new MainLoop();
        s = new MWSerial();
        if(paymax > s.get_txbuf())
            s.set_txbuf((uint16)paymax);
    }

    private void fuzz() {
        bool ok = false;
        uint16 cmd = 0;
        while (!ok) {
            cmd = (uint16)rand.int_range(0, cmdmax);
            if(noevil == 1)
                ok = (cmd != Danger.MSP_REBOOT);
            else if (noevil == 2)
                ok = (cmd < Danger.MSP_REBOOT ||
                      cmd > Danger.MSP_DATAFLASH_ERASE);
            else
                ok = !(cmd in (uint16 [])dangerous);
        }
        uint16 len = (uint16)rand.int_range(0, paymax);
        uint8 [] payl = new uint8[len];
        int msplen = len + ((cmd > 255) ? 9 : 6);
        print("send CMD %u (%x), plen %u (mlen=%u)\n", cmd, cmd, len, msplen);
        s.send_command((MSP.Cmds)cmd,payl, len);
        tid = Timeout.add(2000, () => {
                tid = 0;
                stdout.puts("Timeout ... ");
                fuzz();
                return false;
            });
        ns++;
    }

    private int run() {
        string estr;
        bool res;

        Posix.signal (Posix.SIGINT, (s) => {
                fquit = true;
                Timeout.add_seconds(2, () => {
                        ml.quit();
                        return false;
                    });
            });

        if((res = s.open(dev, baud, out estr)) == true) {
            s.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
                    if(tid != 0) {
                        Source.remove(tid);
                        tid = 0;
                    }
                    nr++;
                    print("recv CMD %u (%x), len %u, err %s\n",
                          cmd, cmd, len, errs.to_string());
                    if(fquit)
                        ml.quit();
                    if(loops != 0 && nr >= loops)
                        ml.quit();
                    else
                        fuzz();
                });

            s.serial_lost.connect(() => {
                    s.close();
                    ml.quit();
                });

            Timeout.add(500, () => {
                    fuzz();
                    return false;
                });

            ml.run ();
            print("\n sent=%u, recv %u\n", ns, nr);
            var ss = s.dump_stats();
            print("%.0fs, rx %lub, tx %lub, (%.0fb/s, %0.fb/s) messages %s\n",
                  ss.elapsed, ss.rxbytes, ss.txbytes,
                  ss.rxrate, ss.txrate,
                  ss.msgs.to_string());
            return 0;
        } else {
            MWPLog.message("open failed serial %s %s\n", dev, estr);
            return 255;
        }
    }

    public static int main (string[] args) {
        string []devs = {"/dev/ttyUSB0","/dev/ttyACM0"};
        foreach(var d in devs) {
            if(Posix.access(d,(Posix.R_OK|Posix.W_OK)) == 0) {
                dev = d;
                break;
            }
        }

        try {
            var opt = new OptionContext(" - msp tester");
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
            opt.parse(ref args);
        } catch (OptionError e) {
            stderr.printf("Error: %s\n", e.message);
            stderr.printf("Run '%s --help' to see a full list of available "+
                          "options\n", args[0]);
            return 1;
        }

        if (args.length > 2)
            baud = int.parse(args[2]);

        if (args.length > 1)
            dev = args[1];

        if(dev == null) {
            stdout.puts("No device found\n");
            return 0;
        }
        return new Fuzzer().run();
    }
}
