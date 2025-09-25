# Playing Video in mwp

{{ mwp }} provides support for live and recorded video. Use cases might include:

* In ground station mode, for long range monitoring;
* In ground station mode, in order to repeat the FPV feed to the mwp screen, presumably for the enjoyment of spectators;
* During Blackbox replay, to show the FPV recorded video during the replay.

Video may be played in either a separate window, or in an embedded pane (FPV Mode).

![FPV View](images/fpvmode/fpv-mode-analogue.avif){: width="30%" }

## Video Player Requirements

mwp uses the open source GStreamer API to provide video playing. As well as any decoders / formats etc. to support the input stream, there is runtime dependency on the `gstgtk4` Gstreamer plugin. This is available on modern operating systems and its package name is OS dependent, for example:

* Arch and MSys2 :  `gst-plugin-gtk4`
* Debian (Sid / Trixie): `gstreamer1.0-gtk4`
* FreeBSD: `gstreamer1-plugins-rust`
* Void: `gst-plugins-rs1`

There is also a fallback video player for older OS (e.g. Ubuntu 24.04). This can also be used on Windows where the graphics driver fails (error message `failed to share contexts through wglShareLists 0xaa`) (any may crash mwp) using the `gstgtk4` Gstreamer / OpenGL plugin.

The "fallback" video widget is based on `Gtk.Video':

* Automatically detects missing `gtk4paintablesink` on Ubuntu 24.04 et al and uses the fallback player.
* On Windows with "bad" graphics drivers (or to force the fallback widget anyway), fallback video requires that the new setting `use-fallback-video` is set to `true`.

Consequences of using the fallback video player:

* On Windows and MacOS, no direct USB camera access
* Higher latency (e.g. 2000ms on RTSP feeds)
* Fewer  video codecs available.

!!! note "Legacy Images"
    The images this section are from legacy mwp, however the capability is the same.

## Live stream mode (GCS)

There is a **Video Stream** option under the view menu.

![View Menu](images/mwp_vid_menu.avif){: width="30%" }

Selecting this option opens the source selection dialogue. Camera devices (i.e most webcams) will be auto-detected. There is also the option to enter a URI, which could be a `http`/`https`, `rtsp` or other standard streaming protocol, or even a file.

![Chooser](images/recent-video.avif){: width="20%" }

The selected source will then play in a separate window. This window will remain above the mwp application and can be resized, minimised and moved.

In stream mode, there are minimal video controls; a play/pause button and volume control. Note the volume is that of the video, the overall volume is controlled by the system volume control.

Up to 10 recent URIs are persisted. In order to access this list it is necessary to click the "expander" icon at the end of URI text entry box. The recent files list is stored in a text file `~/.config/mwp/recent-video.txt`. This file may be maintained with a text editor if required.

In "FPV Mode", no controls are shown.

## Camera Capabilities

mwp requests camera capabilities from Gstreamer and presents them to the user when the "Settings" button clicked.

![settings](images/mwp-video-options.avif)

If a capability is selected, it is passed on to GStreamer verbatim and stored for future use.

## OS Specific

The following GStreamer video sources (at least) are supported:

* Linux. "Video4Linux" (`v4l2src`), pipewire (`pipewiresrc`) and libcamera (`libcamerasrc`)
* FreeBSD. FreeBSD offers a video4linux (`v4l2src`) emulation that works with {{ mwp }}.
* Windows. `ksvideosrc` or  `mfvideosrc` as detected / required.
* MacOS. `avfvideosrc`.

mwp introspects Gstreamer for the required video source and parameters, no user input is required, other than the device specific GStreamer plugin(s) must be installed.

## FPV Mode

FPV mode provides a paned view of a camera feed. The user can switch between "Standard" and "FPV Mode" views from the "View / FPV Mode" menu option or by assigning a [shortcut key](mwp-Configuration.md#keyboard-accelerators), for example in `~/.config/mwp/accels`, the "action" name is "modeswitch", which is here mapped to `F12`.

```
modeswitch F12
```

The [panel](dock.md) will switch as necesary.

FPV uses the following order to determine what to show (if anything).

* If the windowed player was active, that stream is transferred to the video pane.
* Else, if available, the last stream show in the FPV pane is invoked.

### Using RTSP for camera parameter definitions

If the user is using a remote camera, if the camera is not detected or if using Windows with mwp' "fallback" player , then a RTSP server can be used to feed the camera stream to mwp.

[go2rtc](https://github.com/AlexxIT/go2rtc) is a useful RTSP server that supports numerous video options, including format conversion.

#### Linux, FreeBSD

The following sample configuration file `go2rtc.yaml` illustrates some of the possibilities:

```
streams:
  usbcam1: v4l2:device?video=/dev/video0&input_format=mjpeg&video_size=1280x720&framerate=30
  usbcam2: ffmpeg:/dev/video0#video=h264#audio=aac#scale=1280:720
  usbcam3: v4l2:device?video=/dev/video0&input_format=mjpeg&video_size=640x480&framerate=10

  file0: exec:ffmpeg -hide_banner -re -stream_loop -1 -i /home/jrh/Videos/Daria-SurfKayak.mp4 -vcodec h264 -rtsp_transport tcp -f rtsp {output}
  file1: ffmpeg:/home/jrh/Videos/18_ft_Skiff_in_heavy_wind.mp4
  test: exec:ffmpeg -hide_banner -re -f lavfi -i testsrc -vcodec h264 -rtsp_transport tcp -f rtsp {output}
```

The camera is a 10 year old "Mobius"; remember them?

* `usbcam1` : "Normal" camera configuration (MJPEG feed).
* `usbcam2` : Camera feed is transcoded using `ffmpeg` to H264 prior to transmission.
* `usbcam3` : Sets the camera resolution.

And some test streams:

* `file0` : Streams a `webm` video in a loop
* `file1` : Streams a `mp4` video
* `test` : Streams the `ffmpeg` "test card"

It is possible to start and stop `go2rtc` when mwp is started / quit using the `atstart` and `atexit` settings:

Adjust configuration file path for your environment:

* atstart: `go2rtc -c /home/jrh/.config/go2rtc/go2rtc.yaml`
* atexit: `pkill -f go2rtc.exe`

#### Windows

Example `go2rtc` configuration file for USB webcam:

```
streams:
  webcam0: ffmpeg:device?video=0#width=640#height=480#video=mjpeg
  webcam1: ffmpeg:device?video=Mobius#width=640#height=480#video=mjpeg
  webcam2: ffmpeg:device?video=0#width=640#height=480#video=h264
```

Each of the above lines refers to the same device (name/index reference), natural or trans-coded video). At least in the author's VM, it is necessary to downsize the video stream resolution to avoid `ffmpeg` overruns. This may not be necessary on a non-virtualised system.

#### Windows mwp settings to start / stop go2rtc

* atstart: `go2rtc.exe -c c:/Users/win10/go2rtc.yaml'`
* atexit: `taskkill.exe -f -im "go2rtc.exe"`

It is recommended to use POSIX style forward slashes rather than Windows backslash in order to avoid any "backslash escape" issues.

Note that go2rtc and dependencies (`ffmpeg` etc.) must be on a `PATH` available to `mwp.exe`.

## GStreamer debug

Most failures / errors during replay are caused by missing GStreamer plugins. Gstreamer plugin provision is a runtime dependency that should be done by the user. The Windows' installer includes a (ridiculously) large selection of GStreamer plugins, but it's always possible that one is missing.

For the record, on Arch Linux, the following GStreamer packages appear adequate for all sources tested:

* gstreamer
* gst-plugins-ugly
* gst-plugins-good
* gst-plugins-base-libs
* gst-plugins-base
* gst-plugins-bad-libs
* gst-plugins-bad
* gst-plugin-webrtchttp
* gst-plugin-rswebrtc
* gst-plugin-rsrtp
* gst-plugin-pipewire
* gst-plugin-hlssink3
* gst-plugin-gtk4
* gst-libav

Package names / capabilities are OS dependent, the above list is a guide.

The following GStreamer tools are useful to test / debug video sources against installed GStreamer modules.

* `gst-device-monitor-1.0` : Discover device sources, e.g. Cameras.
* `gst-discoverer-1.0` : Discover stream properties.
* `gst-play-1.0` : Play a stream from a URI
* `gst-launch-1.0` : Play a pipeline. Note that mwp reports its constructed pipeline in `mwp_stderr*.txt`

Note: The Windows installer includes these tools.

### Examples of GStreamer debug tools.

Alas, these are all success cases.

#### `gst-device-monitor`

##### Linux, pipewire

```
$ gst-device-monitor-1.0 Video/Source
Probing devices...

Device found:

	name  : Mobius (V4L2)
	class : Video/Source
	caps  : image/jpeg, width=1280, height=720, framerate=30/1
	        image/jpeg, width=640, height=480, framerate=30/1
	        image/jpeg, width=320, height=240, framerate=30/1
	properties:
		is-default = true
		api.v4l2.cap.bus_info = usb-0000:00:14.0-4.4
		api.v4l2.cap.capabilities = 84a00001
		api.v4l2.cap.card = Mobius
		api.v4l2.cap.device-caps = 04200001
		api.v4l2.cap.driver = uvcvideo
		api.v4l2.cap.version = 6.16.5
		api.v4l2.path = /dev/video0
		device.api = v4l2
		device.devids = [ 20736 ]
		device.id = 77
		device.product.id = 0x1002
		device.vendor.id = 0x0603
		factory.name = api.v4l2.source
		media.class = Video/Source
		node.description = Mobius (V4L2)
		node.name = v4l2_input.pci-0000_00_14.0-usb-0_4.4_1.0
		node.nick = Mobius
		node.pause-on-idle = false
		object.path = v4l2:/dev/video0
		priority.session = 1000
		factory.id = 11
		client.id = 41
		clock.quantum-limit = 8192
		node.loop.name = data-loop.0
		media.role = Camera
		node.driver = true
		object.id = 75
		object.serial = 601
	gst-launch-1.0 pipewiresrc target-object=601 ! ...
```

##### Linux, libcamera

Also discovers the `pipewiresrc` option:

```
$ gst-device-monitor-1.0 Video/Source
Probing devices...

Device found:

	name  : Mobius (V4L2)
	    ...
		object.serial = 57
	gst-launch-1.0 pipewiresrc target-object=57 ! ...

Device found:

	name  : \_SB_.PCI0.S11_.S00_-4:1.0-0603:1002
	class : Source/Video
	caps  : image/jpeg, width=320, height=240
	        image/jpeg, width=640, height=480
	        image/jpeg, width=1280, height=720
	properties:
		api.libcamera.SystemDevices = < (gint64)20736 >
		api.libcamera.PixelArrayActiveAreas = < (int)0, (int)0, (int)1280, (int)720 >
		api.libcamera.PixelArraySize = < (int)1280, (int)720 >
		api.libcamera.Location = CameraLocationExternal
		api.libcamera.Model = Mobius
	gst-launch-1.0 libcamerasrc camera-name='\_SB_.PCI0.S11_.S00_-4:1.0-0603:1002' ! ...
```

Note user-hostile name provided by libcamera.

##### Windows

```
PS C:\Users\win10> $env:Path += ";C:\Program Files\mwptools\bin"
PS C:\Users\win10> gst-device-monitor-1.0.exe Video/Source
Probing devices...


Device found:

        name  : Mobius
        class : Video/Source
        caps  : image/jpeg, width=1280, height=720, framerate=30/1, pixel-aspect-ratio=1/1
                image/jpeg, width=640, height=480, framerate=30/1, pixel-aspect-ratio=1/1
                image/jpeg, width=320, height=240, framerate=30/1, pixel-aspect-ratio=1/1
        gst-launch-1.0 ksvideosrc device-path="\\\\\?\\usb\#vid_0603\&pid_1002\&mi_00\#7\&1251d048\&0\&0000\#\{6994ad05-93ef-11d0-a3cc-00a0c9223196\}\\global" ! ...

```

##### MacOS

```
$ gst-device-monitor-1.0 Video/Source
Probing devices...


Device found:

	name  : Mobius
	class : Video/Source
	caps  : video/x-raw(memory:GLMemory), width=1280, height=720, format={ (string)UYVY, (string)YUY2 }, framerate=30/1, texture-target=rectangle
	        video/x-raw(memory:GLMemory), width=640, height=480, format={ (string)UYVY, (string)YUY2 }, framerate=30/1, texture-target=rectangle
	        video/x-raw(memory:GLMemory), width=320, height=240, format={ (string)UYVY, (string)YUY2 }, framerate=30/1, texture-target=rectangle
	        video/x-raw, width=1280, height=720, format={ (string)UYVY, (string)YUY2, (string)NV12, (string)ARGB, (string)BGRA }, framerate=30/1
	        video/x-raw, width=640, height=480, format={ (string)UYVY, (string)YUY2, (string)NV12, (string)ARGB, (string)BGRA }, framerate=30/1
	        video/x-raw, width=320, height=240, format={ (string)UYVY, (string)YUY2, (string)NV12, (string)ARGB, (string)BGRA }, framerate=30/1
	properties:
		device.api = avf
		avf.unique_id = 0x1dd0000006031002
		avf.model_id = UVC Camera VendorID_1539 ProductID_4098
		avf.has_flash = false
		avf.has_torch = false
		avf.manufacturer = C-DUTEK
	gst-launch-1.0 avfvideosrc device-index='0' ! ...
```


#### `gst-discoverer-1.0`

```
$ gst-discoverer-1.0 rtsp://zeropi:8554/test
Analyzing rtsp://zeropi:8554/test
Done discovering rtsp://zeropi:8554/test

Properties:
  Duration: 99:99:99.999999999
  Seekable: no
  Live: yes
  unknown #0: application/x-rtp
    video #1: H.264 (High 4:4:4 Profile)
      Stream ID: a2cb945a1d6a987694fb1a99ae73d9531ecca8c82ec7d7b1a50c27d95f26893f/video:0:0:RTP:AVP:96
      Width: 320
      Height: 240
      Depth: 24
      Frame rate: 25/1
      Pixel aspect ratio: 1/1
      Interlaced: false
      Bitrate: 0
      Max bitrate: 0
```

#### Play camera source discovered above

```
$ gst-play-1.0 v4l2:///dev/video0
Press 'k' to see a list of keyboard shortcuts.
Now playing v4l2:///dev/video0
Pipeline is live.
Redistribute latency...
ERROR Output window was closed for v4l2:///dev/video0
ERROR debug information: ../gstreamer/subprojects/gst-plugins-base/sys/xvimage/xvimagesink.c(586): gst_xv_image_sink_handle_xevents (): /GstPlayBin3:playbin/GstPlaySink:playsink/GstBin:vbin/GstAutoVideoSink:videosink/GstXvImageSink:videosink-actual-sink-xvimage
Reached end of play list.
```

#### Launch mwp constructed pipelines

* Standard, (without `MWP_SHOW_FPS`)
* Logged as `08:05:09.573216 Playbin: pipewiresrc target-object=226 ! image/jpeg, width=1280, height=720, framerate=30/1 ! decodebin ! autovideoconvert !  gtk4paintablesink sync=false`
* Note: If Gstreamer on Linux reports a `pipewiresrc`, then mwp uses that, otherwise it will use  `v4l2src` (see next example). Or `libcamerasrc`.

```
$ gst-launch-1.0 pipewiresrc target-object=226 ! image/jpeg, width=1280, height=720, framerate=30/1 ! decodebin ! autovideoconvert !  gtk4paintablesink sync=false
Setting pipeline to PAUSED ...
MESA-INTEL: warning: Haswell Vulkan support is incomplete
MESA-INTEL: warning: ../mesa-25.2.2/src/intel/vulkan_hasvk/anv_formats.c:759: FINISHME: support YUV colorspace with DRM format modifiers
MESA-INTEL: warning: ../mesa-25.2.2/src/intel/vulkan_hasvk/anv_formats.c:790: FINISHME: support more multi-planar formats with DRM modifiers
Pipeline is live and does not need PREROLL ...
Got context from element 'gtk4paintablesink0': gst.gl.GLDisplay=context, gst.gl.GLDisplay=(GstGLDisplay)"\(GstGLDisplayWayland\)\ gldisplaywayland0";
Got context from element 'gtk4paintablesink0': gst.gl.app_context=context, context=(GstGLContext)"\(GstGLWrappedContext\)\ glwrappedcontext0";
Pipeline is PREROLLED ...
Setting pipeline to PLAYING ...
New clock: pipewireclock0
Redistribute latency...
ERROR: from element /GstPipeline:pipeline0/GstGtk4PaintableSink:gtk4paintablesink0: Output window was closed
Additional debug info:
video/gtk4/src/sink/imp.rs(861): gstgtk4::sink::imp::PaintableSink::create_window::{{closure}}::{{closure}} (): /GstPipeline:pipeline0/GstGtk4PaintableSink:gtk4paintablesink0
Execution ended after 0:00:04.747077581
Setting pipeline to NULL ...
Freeing pipeline ...
```

Debugging framerate with `MWP_SHOW_FPS`

* Logged as: `10:09:23.943487 Playbin: v4l2src device=/dev/video0 ! image/jpeg, width=1280, height=720, framerate=30/1 ! decodebin ! autovideoconvert ! fpsdisplaysink video-sink=gtk4paintablesink text-overlay=true sync=false`

```
$ gst-launch-1.0 v4l2src device=/dev/video0 ! image/jpeg, width=1280, height=720, framerate=30/1 ! decodebin ! autovideoconvert ! fpsdisplaysink video-sink=gtk4paintablesink text-overlay=true sync=false
Setting pipeline to PAUSED ...
MESA-INTEL: warning: Haswell Vulkan support is incomplete
MESA-INTEL: warning: ../mesa-25.2.2/src/intel/vulkan_hasvk/anv_formats.c:759: FINISHME: support YUV colorspace with DRM format modifiers
MESA-INTEL: warning: ../mesa-25.2.2/src/intel/vulkan_hasvk/anv_formats.c:790: FINISHME: support more multi-planar formats with DRM modifiers
Pipeline is live and does not need PREROLL ...
Got context from element 'gtk4paintablesink0': gst.gl.GLDisplay=context, gst.gl.GLDisplay=(GstGLDisplay)"\(GstGLDisplayWayland\)\ gldisplaywayland0";
Got context from element 'gtk4paintablesink0': gst.gl.app_context=context, context=(GstGLContext)"\(GstGLWrappedContext\)\ glwrappedcontext0";
Pipeline is PREROLLED ...
Setting pipeline to PLAYING ...
New clock: GstSystemClock
Redistribute latency...
ERROR: from element /GstPipeline:pipeline0/GstFPSDisplaySink:fpsdisplaysink0/GstGtk4PaintableSink:gtk4paintablesink0: Output window was closed
Additional debug info:
video/gtk4/src/sink/imp.rs(861): gstgtk4::sink::imp::PaintableSink::create_window::{{closure}}::{{closure}} (): /GstPipeline:pipeline0/GstFPSDisplaySink:fpsdisplaysink0/GstGtk4PaintableSink:gtk4paintablesink0
Execution ended after 0:00:07.353664499
Setting pipeline to NULL ...
Freeing pipeline ...
```
