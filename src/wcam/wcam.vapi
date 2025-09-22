[CCode (cheader_filename = "wcam.h")]
namespace WinCam {
	[CCode (cname="get_cameras")]
	string get_cameras();   
}
// , array_length=false, array_null_terminated=true