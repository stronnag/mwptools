[CCode (cheader_filename = "wcam.h")]
namespace WinCam {
	[CCode (cname="get_cameras")]
	int get_cameras(out string[]cams);
}
// , array_length=false, array_null_terminated=true