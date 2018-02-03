// MWP external C functions

[CCode (cheader_filename = "mwpfuncs.h")]
namespace MwpPipe
{
    [CCode (cname = "cf_pipe")]
    int pipe(int *fds);
    [CCode (cname = "cf_pipe_close")]
    int close(int fd);
}

[CCode (cheader_filename = "mwpfuncs.h")]
namespace MwpSerial
{
    [CCode (cname = "flush_serial")]
    void flush(int fd);
    [CCode (cname = "set_fd_speed")]
    int set_speed(int fd, int rate);
    [CCode (cname= "open_serial")]
    int open(string device, uint baudrate);
    [CCode (cname = "set_timeout")]
    void set_timeout(int fd, int tenths, int number);
    [CCode (cname="close_serial")]
    void close(int fd);
    [CCode (cname="get_error_text")]
    unowned string error_text(int err, char *buf, size_t len);
    [CCode (cname="default_name")]
    string default_name();
}

[CCode (cheader_filename = "mwpfuncs.h")]
namespace BTSocket
{
    [CCode (cname="connect_bt_device")]
    int connect(string dev, int* lasterr);
}

[CCode (cheader_filename = "mwpfuncs.h")]
namespace MwpSpeech
{
    [CCode (cname="speech_init")]
    int init(string voice);
    [CCode (cname="speech_say")]
    void say(string text);
    [CCode (cname="get_speech_api_mask")]
    uint8 get_api_mask();
    [CCode (cname="speech_set_api")]
    void set_api(uint8 api);
}

[CCode (cheader_filename = "mwpfuncs.h")]
namespace MwpSignals
{
    [CCode (cname="init_signals")]
    int fd();
}

[CCode (cheader_filename = "stdlib.h")]
namespace MwpLibC
{
    [CCode (cname="atexit")]
    int atexit(GLib.VoidFunc f);
    [CCode (cname="ptsname")]
    unowned string ptsname(int fd);
}

[CCode (cheader_filename = "glib.h")]
namespace DStr
{
    [CCode (cname = "g_strtod")]
    public double strtod(string s, out string t);
}

[CCode (cheader_filename = "mwpfuncs.h")]
namespace MwpVers
{
    [CCode (cname="mwpvers")]
    static string build;
    [CCode (cname="mwpid")]
    static string id;
    [CCode (cname="__progname")]
    string progname;
}
