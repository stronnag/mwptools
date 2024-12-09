// MWP external C functions


[CCode (cheader_filename = "mwpfuncs.h")]
namespace BTSocket {
    [CCode (cname="connect_bt_device")]
    int connect(string dev, int* lasterr);
}

[CCode (cheader_filename = "mwpfuncs.h")]
namespace MwpSpeech {
    [CCode (cname="speech_init")]
    int init(string voice);
    [CCode (cname="speech_say")]
    void say(string text);
    [CCode (cname="speech_close")]
    void close();
    [CCode (cname="get_speech_api_mask")]
    uint8 get_api_mask();
    [CCode (cname="speech_set_api")]
    void set_api(uint8 api);
}

[CCode (cheader_filename = "stdlib.h")]
namespace MwpLibC {
    [CCode (cname="atexit")]
    int atexit(GLib.VoidFunc f);
    [CCode (cname="ptsname")]
    unowned string ptsname(int fd);
    [CCode (cname="strtol")]
	long strtol (string nptr, out char* endptr, int _base);
    [CCode (cname="strtoul")]
	long strtoul (string nptr, out char* endptr, int _base);
}

[CCode (cheader_filename = "glib.h")]
namespace DStr {
    [CCode (cname = "g_strtod")]
    public double strtod(string s, out string? t=null);
}

[CCode (cheader_filename = "mwpfuncs.h")]
namespace MwpVers {
    [CCode (cname="get_build")]
    unowned string get_build();
    [CCode (cname="get_id")]
    unowned string get_id();
    [CCode (cname="get_build_host")]
    unowned string get_build_host();
    [CCode (cname="get_build_compiler")]
    unowned string get_build_compiler();
//    [CCode (cname="__progname")]
//    string progname;
}

[CCode (cheader_filename = "termcap.h")]
namespace Tc {
    [CCode (cname="tgetent")]
    int tgetent(char *id, char *buf);
    [CCode (cname="tgetstr")]
    unowned string tgetstr(char *id, char **buf);
}

[CCode (cheader_filename = "mwpfuncs.h")]
namespace MwpMisc {
    [CCode (cname="is_cygwin")]
    bool is_cygwin();

    [CCode (cname="get_native_path")]
    string get_native_path(string upath);
    public const int MWP_MAX_WP;
}

[CCode (cheader_filename = "rserial.h")]
namespace MwpPipe {
    [CCode (cname = "cf_pipe")]
    int pipe(int *fds);
}

[CCode (cheader_filename = "rserial.h")]
namespace MwpSerial {
    [CCode (cname= "open_serial")]
    int open(string device, uint baudrate);
    [CCode (cname= "read_serial")]
	ssize_t read(int fd, uint8 *buf, size_t buflen);
    [CCode (cname= "write_serial")]
	ssize_t write(int fd, uint8 *buf, size_t buflen);
	[CCode (cname = "flush_serial")]
    void flush(int fd);
    [CCode (cname = "set_timeout")]
    void set_timeout(int fd, int tenths, int number);
    [CCode (cname = "set_fd_speed")]
    void set_speed(int fd, int rate);
    [CCode (cname="close_serial")]
    void close(int fd);
	[CCode (cname="get_error_text")]
    unowned string error_text(int err, char *buf, size_t len);
	[CCode (cname="get_error_number")]
	int get_error_number();
}
