[CCode (cheader_filename = "mwpset-config.h", cname="MWPSET_VERSION_STRING")]
public const string MWPSET_VERSION_STRING;

namespace DStr {
    [CCode (cname = "g_strtod")]
    public double strtod(string s, out string t);
}
