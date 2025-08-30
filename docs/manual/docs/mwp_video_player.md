# Playing Video in mwp

{{ mwp }} provides support for live and recorded video.

* In ground station mode, in order to repeat the FPV feed to the mwp screen, presumably for the enjoyment of spectators;
* During Blackbox replay, to show the FPV recorded video during the replay.

Video may be played in either a separate window, or in an embedded pane (FPV Mode).

## Video Player Requirements

mwp uses the open source GStreamer API to provide video playing. As well as any decoders / formats etc. to support the input stream, there is dependency on the `gstgtk4` Gstreamer plugin. This is available on modern operating systems and its package name is OS dependent, for example:

    * Arch:  `gst-plugin-gtk4`
    * Debian (Sid / Trixie): `gstreamer1.0-gtk4`
    * FreeBSD: `gstreamer1-plugins-rust`
    * Void: `gst-plugins-rs1`

!!! note "Legacy Images"
    The images this section are from legacy mwp, however the capability is the same.

## Live stream mode (GCS)

There is now a **Video Stream** option under the view menu.

![View Menu](images/mwp_vid_menu.png){: width="30%" }

Selecting this option opens the source selection dialogue. Camera devices offering a "video4linux" or (Windows) `ksvideosrc` interface (i.e most webcams) will be auto-detected. There is also the option to enter a URI, which could be a `http`/`https`, `rtsp` or other standard streaming protocol, or even a file.

![Chooser](images/recent-video.png){: width="20%" }

The selected source will then play in a separate window. This window will remain above the mwp application and can be resized, minimised and moved.

In stream mode, there are minimal video controls; a play/pause button and volume control. Note the volume is that of the video, the overall volume is controlled by the system volume control.

Up to 10 recent URIs are persisted. In order to access this list it is necessary to click the "expander" icon at the end of URI text entry box. The recent files list is stored in a text file `~/.config/mwp/recent-video.txt`. This file may be maintained with a text editor if required.

In "FPV Mode", no controls are shown.

## OS Specific

* FreeBSD. FreeBSD offers a video4linux emulation that works with {{ mwp }}. Cameras are not auto-detected but will be recognised if plugged in before mwp is invoked.
* Windows. Uses `ksvideosrc` for input. The more modern `mfvideosrc` is not used, as it may not be universally available.
* MacOS. Camera input is unlikely to work.
