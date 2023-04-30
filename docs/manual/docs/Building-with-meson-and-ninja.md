# Build / install mwp (Generic)

## Overview

If you just want to install {{ mwp }} on a Debian /derivative (includin WSL), x64_64, then you can install the binary `.deb` package from the [Release Area](https://github.com/stronnag/mwptools/releases).

Otherwise, if you're using a different (not Debian based) distribution, just curious about building mwptools, you want to explore other tools and scripts in the repository or you're using a different architecture (ia32, Arm7, aarch64, riscV, ppc etc.), then you can build from source.

For Arch Linux, you can install using the AUR package `mwptools-git`

The **mwptools** suite is built using the [meson](https://mesonbuild.com/SimpleStart.html) and [ninja](https://ninja-build.org/) toolchain. For most users these will be automatically provided by a `build-essentials` type of package transparently to the user.

Prior to late May 2021, the build system used a convoluted `Makefile`.

For Debian and derivatives there is a ["one stop" installation script](#easy-first-time-install-on-debian-and-ubuntu), as well as a x86_64 "Release" `.deb` archive.

## Rationale

In its early days, `make` was a suitable build tool. As **mwptools** has gained in features and functionality, this has become un-maintainable.
The migration to `meson` and `ninja` solves this problem and allows the project structure to be rationalised.

## Usage

### Migration (for old Make based installs)

If you're updating an old Makefile based install, please ensure your extant mwptools instance does not have untracked files:

    git clean -fd -fx
    git pull

### First time

Set up the `meson` build system from the top level:

    meson build --buildtype=release --strip [--prefix $HOME/.local]

* For a user / non-system install, set `--prefix $HOME/.local`
    - This will install the binaries in `$HOME/.local/bin`, which should be added to `$PATH` as required.
* For a Linux system wide install, set `--prefix /usr`
* For FreeBSD (*BSD), for a system-wide install,  don't set `--prefix` as the default (`/usr/local`) is suitable

Unless you need a multi-user setup, a local install is preferable, as you don't need `sudo` to install, and you'll not risk messing up build permissions.

* If you're using a really old OS (e.g. Debian 10), you may also need `export XDG_DATA_DIRS=/usr/share:$HOME/.local/share` for a local install.

### "Easy" first-time install on Debian and derivatives

* Download the [first time build script](https://raw.githubusercontent.com/stronnag/mwptools/master/docs/deb-install.sh)
* Make it executable `chmod +x deb-install.sh`
* Run it `./deb-install.sh -y`
* Note that the script may ask for a password to install system packages
* The resulting executables are in `~/.local/bin`. Ensure this exists on `$PATH`; modern distros should do this for you.
* If you get messages like `Removing /home/$USER/.config/mwp/.layout.xml 0` and `Failed to save layout, remains in /tmp/.mwp.xxxxxx.xml` you also need `export XDG_DATA_DIRS=$XDG_DATA_DIRS:$HOME/.local/share`. This is rare and should not occur on [supported platforms](mwp_support.md#supported-os).

### Build and update

    cd build
    # for a local install (and cygwin)
    ninja install
    # for system install
    ninja && sudo ninja install

### Accessing the serial port

The user needs to have read / write permissions on the serial port in order to communicate with a flight controller. This is done by adding the user to a group:

* Arch Linux: `sudo usermod -aG uucp $USER`
* Debian / Fedora (and derivatives): `sudo usermod -aG dialout $USER`
* FreeBSD: `sudo pw group mod dialer -m $USER`
* Windows/WSL: Not needed, no serial pass-through. Use the [ser2udp](mwp-in-Windows-11---WSL-G.md#serial-device) bridge instead.

### Legacy

For now, some of the legacy `Makefiles` remain, and can be used similar to before, e.g. :

    cd mwptools/src/mwp
    make && sudo make install

At some stage, more of the Makefiles will be removed (or just rot into uselessness).

## Files built / installed

### Default

| Application | Usage |
| ----------- | ----- |
| `mwp` | Mission planner, GCS, log replay etc. |
| `mwp-area-planner` | Survey planner |
| `mwp-plot-elevations` [1](#note1) | Mission elevation / terrain analysis |
| `qproxy` | Proxy for certain commercial TMS |
| `cliterm` | Interact with the CLI |
| `fc-get`, `fc-set` [2](#note2) | Backup / restore CLI diff |
| `inav_states.rb` | Summarise BBL state changes, also installed `inav_states_data.rb` |
| `fcflash` | FC flashing tool, requires `dfu-util` and / or `stmflash32` |
| `flashgo` | Tools to examine, download logs and erase from dataflash |

!!! note "Notes:"
    <a name="note1">1.</a> This may either be the new Go executable or the legacy, less functional Ruby script.

	<a name="note2">2.</a> `fc-set` is a hard link to `fc-get`

### Optional

These are only built by explicit target name; they will be installed if built.

    # one of more of the following targets
    ninja bproxy ublox-geo ublox-cli
    sudo ninja install

| Application | Usage |
| ----------- | ----- |
| `bproxy` | Black tile map proxy, for those anonymous needs |
| `ublox-cli` | Ublox GPS tool |
| `ublox-geo` | Graphical Ublox GPS tool |


### Troubleshooting and Hints

#### Migrate from a system install to a user install

    cd build
    sudo ninja uninstall
    meson --reconfigure --prefix=$HOME/.local
    ninja install

#### Fixing build permissions

If you install to system locations, it is possible that `sudo ninja install` will write as `root` to some of the install files, and they become non-writable to the normal user.

* In the `build` directory, run `sudo chown -R $USER .`
* Consider migrating to a local install

### Help!!!!

#### You've installed a new version but you still get the old one!

If you used the `deb-install.sh` script, then it installed everything into `$HOME/.local/bin` (and other folders under `~/.local`). This is  nice because:

* mwp does not pollute the system directories;
* you don't need `sudo` to install it.

Linux (like most other OS) has the concept of a `PATH`, a list of places where it looks for executable files). You can see this from a terminal:


    ## a colon separated list
    echo $PATH

So check that `$HOME/.local/bin` is on `$PATH`; preferably near the front.

If it is, then the problem may be  that the older mwp also exists elsewhere on the PATH, and the system will not re-evaluate the possible chain of locations if it previously found the file it wants.

So, maybe you have an old install. You didn't remove it (alas); so the system thinks that mwp is `/usr/bin/mwp`; in fact it's now `$HOME/.local/bin/mwp`

If `$HOME/.local/bin` is on the PATH before `/usr/bin`, the you have two choices:


    # reset the path search
    hash -r
    # mwp, where art thou? Hopefully now is ~/.local/bin
    which mwp
    # From **this terminal** executing mwp will run the location reported by `which mwp`

or

Log out, log in. The PATH will be re-evaluated.

If `$HOME/.local/bin` is not on PATH. then it needs to be added to a login file (`.profile`, `.bashrc`, `.bash_profile` etc.). Modern distros do this for you, however if you've updated an older install you may have to add it yourself.

    # set PATH so it includes user's private bin if it exists
    if [ -d "$HOME/bin" ] ; then
        PATH="$HOME/bin:$PATH"
    fi

    # set PATH so it includes user's private bin if it exists
    if [ -d "$HOME/.local/bin" ] ; then
        PATH="$HOME/.local/bin:$PATH"
    fi

If an older (perhaps Makefile generated) mwp exists; then you should remove all evidence of an earlier system install.


    find /usr -iname \*mwp\*

review the list and as root, delete the old files. Do similar for blackbox-decode.

If you're content with the list, then (*caveat emptor*):

    sudo find /usr -iname \*mwp\* -delete

You'll still have to remove non-empty directories manually.

#### "ninja: error: loading 'build.ninja': No such file or directory

Something, or persons unknown has removed this file.

    cd mwptools
    meson setup --reconfigure  build --prefix ~/.local
    cd build
    ninja install

#### ERROR: Dependency "?????" not found, tried pkgconfig

{{ mwp }} requires a new dependency. This will be documented in the wiki [Recent Changes](https://github.com/stronnag/mwptools/wiki/Recent-Changes) document.

* Install the newly required dependencies
* Rerun your build

### Supporting data files

| File | Target | Usage |
| ---- | ------ | ----- |
| `src/common/mwp_icon.svg` | `$prefix/share/icons/hicolor/scalable/apps/` | Desktop icon |
| `src/mwp/org.mwptools.planner.gschema.xml` | `$prefix/share/glib-2.0/schemas/` | Settings schema |
| `src/mwp/vcols.css` | `$prefix/share/mwp/` | Colours used by battery widget |
| `src/mwp/default.layout` | `$prefix/share/mwp/` | Default dock layout |
| `src/mwp/beep-sound.ogg` | `$prefix/share/mwp/` | Alert sound  |
| `src/mwp/bleet.ogg` | `$prefix/share/mwp/` | Alert sound  |
| `src/mwp/menubar.ui` | `$prefix/share/mwp/` | Menu definition |
| `src/mwp/mwp.ui` | `$prefix/share/mwp/` | UI definition |
| `src/mwp/orange.ogg` | `$prefix/share/mwp/` | Alert sound  |
| `src/mwp/sat_alert.ogg` | `$prefix/share/mwp/` | Alert sound  |
| `src/mwp/mwp.desktop` | `$prefix/share/applications/` | Desktop launcher |
| `src/mwp/mwp_complete.sh` | `$prefix/share/bash-completion/completions/` | bash completion for `mwp` |
| `src/mwp/pixmaps` | `$prefix/share/mwp/pixmaps/` | UI Icons |
| `src/mwp/blackbox_decode_complete.sh` | `$prefix/share/bash-completion/completions/` | bash completion for `blackbox-decode` |
| `src/samples/area-tool/mwp_area_icon.svg` | `$prefix/share/icons/hicolor/scalable/apps/` | Desktop icon |
| `src/samples/area-tool/mwp-area-planner.desktop` | `$prefix/share/applications/` | Desktop launcher |
| `docs/mwptools.pdf` | `$prefix/share/doc/mwp/` | (Obsolete) manual |
| `docs/debian-ubuntu-dependencies.txt` | `$prefix/share/doc/mwp/` | Debian / Ubuntu dependencies |
| `docs/fedora.txt` | `$prefix/share/doc/mwp/` | Fedora dependencies |
