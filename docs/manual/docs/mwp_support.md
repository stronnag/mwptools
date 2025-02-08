# Troubleshooting and Support

## Troubleshooting

* Please ensure you've completed all the steps in the [installation guide](Building-with-meson-and-ninja.md).
* The [migration guide](mwp-Gtk4-migration-guide.md) provides some useful hints for the current  Gtk4 based mwp.
* Please read the [Help](Building-with-meson-and-ninja.md#help) section in the [installation guide](Building-with-meson-and-ninja.md)
* There are a couple of articles on (rare) serial issues on the wiki:
    * [Serial USB Checklist](https://github.com/stronnag/mwptools/wiki/Serial-USB-checklist)
	* [Serial USB Rarely asked questions](https://github.com/stronnag/mwptools/wiki/Serial-USB-RAQ)

## Support

### How, where

* [**GitHub Issues preferred**](https://github.com/stronnag/mwptools/issues)
* [irc.libera.chat #mwptools](ircs://irc.libera.chat/mwptools)
* Most likely you will be requested to raise a [GitHub Issue](https://github.com/stronnag/mwptools/issues) for non-trivial cases or if there is an [Information requirement](#information-requirements). Hint, you can easily cut out the middle-man here.
* Ensure you're running the latest `master` version.
* See also [Information requirements](#information-requirements). Without this information, it is unlikely that any, non-trivial, support can be given. Please note that images are unlikely to be helpful compared to log files.

### "Supported" OS

* Arch Linux
* Alpine Linux (Edge)
* Chimera Linux
* Debian Testing (`trixie`, `sid`), and contemporaneous derivatives.
* Fedora latest
* FreeBSD latest `RELEASE`
* Supported Desktop Enviroment / Window Managers: basically must comply with XDG standards, specifically GNOME, KDE, xfce, LXqt, labwc, wayfire.

#### Tolerated / Unsupported OS

* Windows (via Msys2)
* MacOS (Homebrew)

### Supported infrastructure

* Native hardware (x64_x86, ia32, aarch64, riscv64).
* Open source OS (Linux or FreeBSD)
* Non-proprietary video driver.
* qemu/kvm virtualised instances.
* Little endian (big endian never tested).
* Recent release of mwp

### Information requirements

#### Clear description of the issue

* A step of steps to reproduce the issue
* The actual and expected outcomes
* Include {{ mwp }}'s console log, from your home directory (`Documents\mwp` for Windows), `mwp_stderr_YYYY-MM-DD.txt`, e.g. `$HOME/mwp_stderr_2021-12-28.txt`. **Do not delete** any information from this file; the contents are there for a purpose. Or paste the whole terminal output into a file (or copy / paste into the issue). The terminal output may include information from system components that are not the mwp log (e.g. GDK / GTK / Wayland messages).
* If your issue concerns telemetry, include a sample of data that causes the issue. Raw logs may be captured with the `--raw-log` option.
* If you're having a problem playing a blackbox log (or other flight log), include the problematic log.

Issues that do not meet these information requirements most likely be ignored / closed without explanation.

### Unsupported

* Anything else!

Problem reports on non-supported platforms may receive some consideration, however it's unlikely that too much time be expended on such environments unless the problem can also be demonstrated on a supported platform (or it's an interesting issue). Compliance with the Information requirements above is mandatory.
