# Installing mwptools on MacOS

## OS requirements

A version of MacOS supporting `homebrew`, e.g.

### Apple Silicon

* Sequoia
* Sonoma
* Ventura

# X86_64

* Sonoma
* Ventura

At the time of writing, Homebrew does not officially support Sequoia for (most of) the packages required, however, the required packages (and mwp) work well on Sequoia / X86_64.

## Install HomeBrew

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

or use the official package from the Homebrew release area.

### Dependencies

```
brew install gtk4 \
 libshumate \
 libsoup \
 git \
 meson \
 libadwaita \
 libsecret \
 vala \
 protobuf-c \
 libpaho-mqtt \
 gstreamer \
 go \
 espeak-ng \
 vte3 \
 librsvg \
 adwaita-icon-theme \
 sdl2 \
 readline \
 gnuplot
```

Note: homebrew does not supply the librsvg VAPI (vala API) files. It will be necessary to build it from sources (or copy the files from a Linux box).

#### Optional / Recommended

```
brew install bash-completion
```

### Blueprint compiler

The required `blueprint-compiler` is not in `homebrew`, so is install locally:

**Note:** If you have a pre-existing python, then the packages installed above may fail to install the dependency `pygobject3` and you will have to install it manually, either via `brew` or `pipx`.

```
git clone https://gitlab.gnome.org/jwestman/blueprint-compiler
cd blueprint-compiler/
meson setup _build
sudo ninja -C _build install
```

### Build mwp

Only local install is "supported".

* Clone the repository
* Checkout the **development** branch (for now)
* `cd mwptools`

```
meson setup _build --buildtype=release --strip --prefix=~/.local
ninja -C _build install
```

#### One off post install

* It is necessary to add `$HOME/.local/bin` to `$PATH`
* mwp's `gsettings` does not work on MacOS (or more strictly, it does, but `mwp` and `gsettings` do not share storage, which is not helpful). Therefore mwp is using an `ini` file backend on MacOS. A default `ini` file will be installed on first use.
* To set settings outside of mwp, you may edit  `~/.config/mwp/mwp.ini` **with care** as there is no error checking.
* Install `mwp.app`. This adds `mwp` to `Finder` etc.
  ```
  cd /Applications
  tar -xf <PATH TO>/mwptools/docs/mwp.app.tar.gz
  ```

## Other notes

macOS appears not measure text width in the same was a other OS. A "fudge factor" is included that works on my MacOS VMs. The user set there own value with the environment variable `MWP_MAC_FACTOR', set to a value greater than 100. Try with values around 125.

e.g.
```
mwp MWP_MAC_FACTOR=128
```
Once a suitable value is found:

* Reset panel sizing `rm -f ~/.config/mwp/.paned`
* If required, add the `MWP_MAC_FACTOR` environment variable to `~/.config/mwp/cmdopts`

On Ventura, the menus may behave strangely, to the point of being almost unusable. This may be mitigated by setting the environment variable `MWP_MAC_NO_NEST` (to anything).

`libsrecret` and other Dbus related services are not available.


[mwpset](mwpset.md) is recommended to edit mwp's `gsettinngs`.
