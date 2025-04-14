## Overview

{{ mwp }} has, since December 2024, had somewhat functional support for  building `mwptools` using the Windows [Msys2](https://www.msys2.org/) toolchain with the aim of providing a native Windows version of mwp.

* A "portable" Windows Installer is published in the "Snapshot" builds (Github release area).
* May be built locally using the [Msys2](https://www.msys2.org/)

## Status

Somewhat experimental, however most things work.

## Building

It is necessary to install the [Msys2](https://www.msys2.org/) toolchain.

### System Build Dependencies

Add `export LC_ALL=C.utf8` to `.profile` so the `blueprint` UI definitions will compile.
Set your Msys terminal to UTF-8 as well (Options from the title bar icon)
![Screenshot From 2024-12-04 21-13-24](https://github.com/user-attachments/assets/2114bc69-b419-4f1c-8bf1-1873c6241180)

Then install dependencies.

```
 pacman -S  --needed mingw-w64-ucrt-x86_64-gtk4 mingw-w64-ucrt-x86_64-gstreamer mingw-w64-ucrt-x86_64-cairo \
   mingw-w64-ucrt-x86_64-pango mingw-w64-ucrt-x86_64-mosquitto mingw-w64-ucrt-x86_64-libshumate \
   mingw-w64-ucrt-x86_64-libadwaita mingw-w64-ucrt-x86_64-libsecret mingw-w64-ucrt-x86_64-libsoup3 git \
   mingw-w64-ucrt-x86_64-vala mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-go \
   mingw-w64-ucrt-x86_64-blueprint-compiler mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-gtk4-media-gstreamer mingw-w64-ucrt-x86_64-librsvg \
   mingw-w64-ucrt-x86_64-sdl2-compat mingw-w64-ucrt-x86_64-readline
```

Optional, but recommended:
```
pacman -S --needed unzip mingw-w64-ucrt-x86_64-ruby
```
* Note that the packages are (mainly) prefixed `mingw-w64-ucrt-` (vice standard Arch Linux).

Then follow the documented build instructions using `meson` and `ninja`.

### PKGBUILD

There is also a `pacman` `PKGBUILD` file in the `docs/windows-pkg` directory. You can build your own [Msys2](https://www.msys2.org/) package (currently from the `development` branch) using this `PKGBUILD`.

* Create / enter a build directory, any name your like, e.g.
   ```
    mkdir msys-builds && cd msys-builds
    ```
* Copy `docs/windows-pkg/PKGBUILD` there:
    ```
	cp <PATHTO>/mwptools/docs/windows-pkg ./
    ```
* Now you can build the package:
    ```
    makepkg-mingw -C -f
    ```
    This will generate a [Msys2](https://www.msys2.org/) packag named like (the name includes a git tag and commit id)  `mingw-w64-x86_64-mwptools-24.12.02.r76.c1e34843-1-any.pkg.tar.zst` which can be installed with `pacman`
    ```
    pacman -U mingw-w64-x86_64-mwptools-24.12.02.r76.c1e34843-1-any.pkg.tar.zst
    ```
* Note that you can build and install in one command:
    ```
   makepkg-mingw -C -f -i
    ```
After you've done this once, subsequently, after the repo has been updated, you can rerun the build / package generation by rerunning `makepkg-mingw` (and `pacman` to install) as required.

### Windows Installer

A Windows Installer may be provided.

Run the installer. Select the option to install a desktop icon if you wish. Options are provided for a System or Portable (user local) installation.

* If you select a portable (user local) installation, the "DejaVu Mono" fonts cannot be installed, resulting in an ugly side panel.
* The portable (user local) installation may be removed by deleting the installation directory.
* The installer may not set the "Start In" directory correctly.

#### Binary Components and Open Source Licences

The Windows installer includes components distributed under various Open Source
Licences:

The following  binary components are from the [Msys2](https://www.msys2.org/) Project.

* Gtk and dependencies: LGPL2 see [https://gitlab.gnome.org/GNOME/gtk](https://gitlab.gnome.org/GNOME/gtk)
* DejuVu Fonts: Bitsream Licence and other see [https://dejavu-fonts.github.io/License.html](https://dejavu-fonts.github.io/License.html)
* miniunzip: Zlib see  [https://www.winimage.com/zLibDll/minizip.html](https://www.winimage.com/zLibDll/minizip.html)
* Gstreamer : LGPL2 see [https://gstreamer.freedesktop.org](https://gstreamer.freedesktop.org)

Also included (replay tools):

* INAV `blackbox_decode` : GPL3 [https://github.com/iNavFlight/blackbox-tools](https://github.com/iNavFlight/blackbox-tools)
* `fl2ltm` : GPL3 [https://github.com/stronnag/bbl2kml](https://github.com/stronnag/bbl2kml)

## Post Install Tasks

### PKGBuild / Msys 2 local build

* Install any required GStreamer packages
* Install `blackbox_decode` and `fl2ltm`
* Install the DejuVu **`Mono`** fonts as Windows fonts

### All installation methods

#### Audio

Voice assistance requires a spawned "audio (text to speech) helper". The following third party tools are suitable.

* [voice.exe](https://www.elifulkerson.com/projects/commandline-text-to-speech.php) an open source program by Eli Fulkerson uses the Windows Speech Synthesis engine, and works perfectly. Sounds great (similar to `piper-tts` on Linux). The `--voice-command`  option may be set permanently in `%LOCALAPPDATA%\mwp\cmdopts`, for example:
    ```
        # -m option gives a female voice ... (voice -h for other options)
		--voice-command "voice.exe -m"
    ```
* The Windows [espeak](https://netix.dl.sourceforge.net/project/espeak/espeak/espeak-1.48/setup_espeak-1.48.04.exe) port also works as an external helper via `--voice-command espeak` (having set an appropriate `PATH`). The voice is somewhat robotic. The `--voice-command`  option may be set permanently in `%LOCALAPPDATA%\mwp\cmdopts`, for example:
    ```
        --voice-command espeak.exe
    ```

#### Terrain Plots (Terrain Analysis / Line of sight)

Requires a third party `gnuplot`. The `gnuplot` in Mys2 behaves somewhat strangely and is not suitable. [Gnuplot Windows binary](http://tmacchant33.starfree.jp/gnuplot_bin.html). Install the **Msys2 version**.

#### PATH

The above external applications will need to be on the `PATH` available to the installed mwp.

## Known issues

* Bluetooth in general may be unreliable, in some part due to the difficulty in consistently enumerating BT devices.
* BLE is not available
* Terrain Analysis and Line of Sight Analysis is only available "off-line"
* In the event that mwp should crash, it may leave behind some spawned applications, for example one of more of `fl2ltm`, `blackbox_decode`, `espeak`, `voice`, `bproxy`, `gmproxy`, `gdbus`. In particular, mwp may not restart if an `gdbus` orphaned remains. In such cases, the user is advised to clean up using the Task Manager.

## Data Locations

### Configuration Files

* `%UserProfile%\AppData\Local\mwp` / `$LOCALAPPDATA/mwp` (`~/.config/mwp` on POSIX systems).

### Map caches:

* `%UserProfile%\AppData\Local\Microsoft\Windows\INetCache` / `$LOCALAPPDATA/Microsoft/Windows/INetCache` (`~/.cache` on POSIX systems).
* And sub-directories:
    * `shumate` : Tile caches
	* `mwp/DEMs` : Digital Elevation Models (aka Terrain data)

Neither of these locations are cleared by an uninstall.

## Settings

{{ mwp }} maintains [documented settings](mwp-Configuration.md) in a Registry like Gtk component which can be assessed by the command line tool `gsettings`. If you use Msys2, this will be installed. If you use the installer it is also  installed; but it is necessary to establish its path to use it (and enable it to find the settings):

* The mwp Windows Installer will install `gsettings`, this will need `C:\Program Files\mwptools\bin` to be on the `PATH` or `cd  "C:\Program Files\mwptools"` and invoke `bin/gsettings`.  e.g.:

    ```
    PS C:\Users\win11> $env:Path += ";C:\Program Files\mwptools\bin"
    PS C:\Users\win11> gsettings list-recursively org.stronnag.mwp
    org.stronnag.mwp adjust-tz true
    ...
	## show current in the voltage box ...
	PS C:\Users\win11> gsettings set org.stronnag.mwp smartport-fuel-unit 'mAh'
    ```

You may also the graphical [mwpset](mwpset.md) application to maintain settings.

## Other

Note that mwp creates and consumes IP services. It may be necessary to ensure that `mwp.exe` is white-listed in the Windows firewall.

## Reporting Issues

Please see the [general guidance](mwp_support.md), in particular:

* Build issues require the full build text, not just some random subset
* Run time issues require the "stderr" log (`mwp_stderr_YYYY-MM_DD.txt`) as well as any artefacts that cause an issue (BBL, ETX log, mission files etc.).

Previously, these folders defaulted to GLib's `Environment.get_home_dir()` which was `$HOME` / `%HOME%` everywhere.
Now they default to:

* Normal (POSIX) OS: `Environment.get_home_dir()` aka `$HOME`
* Windows: `Environment.get_user_special_dir(UserDirectory.DOCUMENTS)/mwp`  which is `Documents/mwp` . This means for Msys2, you now get the same directory regardless of whether you're the Windows user or the Msys2 user (i.e. `c:/Users/<NAME>/Documents/mwp`.

The user may change the log location via the Environment Variable `MWP_LOG_DIR`.
