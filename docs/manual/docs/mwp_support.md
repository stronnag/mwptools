# Troubleshooting and Support

## Troubleshooting

* Check the [release note on the wiki](https://github.com/stronnag/mwptools/wiki/Recent-Changes) for new dependencies.
* Please ensure you've completed all the steps in the [installation guide](Building-with-meson-and-ninja.md).
* Please read the [Help](Building-with-meson-and-ninja.md#help) section in the [installation guide](Building-with-meson-and-ninja.md)
* There are a couple of articles on (rare) serial issues on the wiki:
    * [Serial USB Checklist](https://github.com/stronnag/mwptools/wiki/Serial-USB-checklist)
	* [Serial USB Rarely asked questions](https://github.com/stronnag/mwptools/wiki/Serial-USB-RAQ)

## Support

### First steps

There is a "rolling release" [release note on the wiki](https://github.com/stronnag/mwptools/wiki/Recent-Changes). Please check that your issue is not due to a new dependency or requirement since your previous installation.

### How, where

* GitHub issues preferred
* RCG, INAV discord and telegram
    * Most likely you will be requested to raise a GitHub issue for non-trivial cases.

### Supported OS

* Arch Linux
* Debian Stable and later (`testing`, `sid`)
* Ubuntu latest and latest LTS (prior release where latest is also LTS).
* Fedora latest
* FreeBSD latest `RELEASE`

### Supported infrastructure

* Native hardware (x64_x86, ia32, aarch64).
* Non-proprietary video driver.
* qemu/kvm virtualised instances.
* Little endian (big endian never tested).

### Information requirements

Where relevant, please include {{ mwp }}'s console log, from your home directory, `mwp_stderr_YYYY-MM-DD.txt`, e.g. `$HOME/mwp_stderr_2021-12-28.txt`. Please do not delete any information from this file; the contents are there for a purpose, or paste the terminal output into a file (or copy paste into the issue). The terminal output may include information from system components that are not the mwp log (e.g. GDK / GTK / Wayland messages).

### Unsupported

* Anything else!

Problem reports on non-supported platforms will not be dismissed without _some_ consideration, however it's unlikely that too much time be expended on such environments unless the problem can also be demonstrated on a supported platform.

### Wayland / XLib

Different behaviours may be experienced using different display environments.

mwp (and other applications) can have a problem with OpenGL and the Wayland compositor. Typically this is manifest by being unable to pick mission WP icons for large (>40 point) missions.

On non-WSL platforms, mwp forces XWayland over Wayland to mitigate this. You can force Wayland / XWayland by setting the `GDK_BACKEND` variable in `cmdopts` (or the environment). This will override mwp's default behaviour.

    # set XWayland
    GDK_BACKEND=x11
	# ** or **
    # set Wayland
    GDK_BACKEND=wayland

If that improves matters, add the setting to [the configuration file](mwp-Configuration.md#cmdopts).
