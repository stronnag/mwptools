# mwp on Cygwin

From 2015-12-30, it is possible to build and run pretty much all of the mwptools suite in [cygwin](https://www.cygwin.com/). It is the best performing Windows option.

* Runs from a desktop short cut
* Audio works
* Easy device names translation

## Installation

* Install the required packages. The file
  `cygwin-example-packages.txt.gz` is taken from a cygwin installation
  that is capable of building and running mwp. Note that while this seems like a large list, many of the items are automagically installed as dependencies of other items. See also [Automation Hints](#automation-hints) below.

* At run time, you need to have started the a X server. [MobaXterm](https://mobaxterm.mobatek.net) is recommended for its stability and performance (and OpenGL hardware suport). VcXsrv is a less stable alternative.

* Serial devices must be prefixed /dev/ and are zero indexed, e.g. `COM3:` => `/dev/ttyS2`

Once the dependencies are installed, mwp is easily built from the cygwin shell:

* Clone the repository
* `make && make install`


### Automation hints

It's quite easy to install the dependencies as follows:

* Install the base cygwin package using the graphical installer from [cygwin](https://www.cygwin.com/).

* Install a few (additional) packages `git`, `wget` and `gzip`, using the graphical installer.

* Open the cygwin terminal

* Fetch and make executable the `apt-cyg` script

  ```
  wget https://rawgit.com/transcode-open/apt-cyg/master/apt-cyg
  install apt-cyg /bin
  ```
* Clone the mwp repsoitory

  ```
  git clone --depth 1 https://github.com/stronnag/mwptools
  ```

* Install all the dependencies in one hit:

  ```
  apt-cyg install $(zcat mwptools/docs/cygwin-example-packages.txt.gz)
  ```

* Build mwp

  ```
  cd mwptools
  make && make install # no sudo in cygwin
  ```

# Runtime

It's convenient to set the following in `.bashrc`

```
export DISPLAY=:0
export NO_AT_BRIDGE=1
# for VcXsvr, MobaXterm does not need it.
export LIBGL_ALWAYS_INDIRECT=Y
# check you have a docs/mwp.bat without "bash -i", otherwise this is fork bomb :)
if test -z "$DBUS_SESSION_BUS_ADDRESS" ; then
 exec dbus-run-session -- bash
fi
```
The X server (MobaXterm, VcXsrv) must be running, it may be convenient to start this automatically from the Windows Startup directory (for VcXsrv).

A Windows batch file is provided that may be used as a desktop shortcut `docs/mwp.bat`

A Windows icon is provided (`common/mwp_icon.ico`)

![mwp on WSL](images/mwp-cygwin.png)


No support is offered for running under cygwin.
