[CCode (cname="cam_dev_t", cheader_filename = "wcam.h")]
public struct CamDev {
  string dspname;
  string devname;
}

[CCode (cheader_filename = "wcam.h")]
namespace WinCam {
	[CCode (cname="get_cameras")]
	public CamDev[] get_cameras(out int res);
}
