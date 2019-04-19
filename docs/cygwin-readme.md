# mwp and cygwin

From 2015-12-30, it is possible to build and run pretty much all of the mwptools suite in [cygwin](https://www.cygwin.com/). It is the best performing	 Windows option.

* Runs from a desktop short cut
* Audio works 
* Easy device names translation

## Installation

* Install the required packages. The file
  `cygwin-example-packages.txt.gz` is taken from a cygwin installation
  that is capable of building and running mwp. Note that while this seems like a large list, many of the items are automagically installed as dependencies of other items.

* At run time, you need to have started the a X server (VcXsrv recommended)

* Serial devices must be prefixed /dev/, e.g. `COM7:` => `/dev/ttyS7`

Once the dependencies are installed, mwp is easily build from the cygwin shell:

* Clone the repository
* `make && make install`

# Runtime

A Windows batch file is provided that may be used as a desktop shortcut `docs/mwp.bat`

A Windows icon is provided (`common/mwp_icon.ico`)




![mwp on WSL](mwp-cygwin.png)


No support is offered for running under cygwin.
