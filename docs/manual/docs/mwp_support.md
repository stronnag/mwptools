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

* [**GitHub Issues preferred**](https://github.com/stronnag/mwptools/issues)
* INAV discord (#off-topic)
    * Most likely you will be requested to raise a [GitHub Issue](https://github.com/stronnag/mwptools/issues) for non-trivial cases or if there is an [Information requirement](#information-requirements). Hint, you can cut out the middle-man here.
* See also [Information requirements](#information-requirements)

### Supported OS

* Arch Linux
* Debian Stable and later (`testing`, `sid`)
* Ubuntu latest and latest LTS (prior release where latest is also LTS).
* Fedora latest
* FreeBSD latest `RELEASE`

### Supported infrastructure

* Native hardware (x64_x86, ia32, aarch64, riscv64).
* Non-proprietary video driver.
* qemu/kvm virtualised instances.
* Little endian (big endian never tested).

### Information requirements

Where relevant, please include {{ mwp }}'s console log, from your home directory, `mwp_stderr_YYYY-MM-DD.txt`, e.g. `$HOME/mwp_stderr_2021-12-28.txt`. Please do not delete any information from this file; the contents are there for a purpose, or paste the terminal output into a file (or copy paste into the issue). The terminal output may include information from system components that are not the mwp log (e.g. GDK / GTK / Wayland messages).

If you're having a problem playing a blackbox log, any reports that do not include the log will most likely be ignored.

### Unsupported

* Anything else!

Problem reports on non-supported platforms will not be dismissed without _some_ consideration, however it's unlikely that too much time be expended on such environments unless the problem can also be demonstrated on a supported platform (or it's an interesting issue).

### Wayland / XLib

Different behaviours may be experienced using different display environments.

mwp (and other applications) can have a problem with OpenGL and the (older versions of the GNOME) Wayland compositor. Typically this is manifest by being unable to pick mission WP icons for large (>40 point) missions. This problem does not appear on other compositors (`wlroots`, WSL) and appears fixed 2023-10.

You can force Wayland / XWayland by setting the `GDK_BACKEND` variable in `cmdopts` (or the environment). This will override mwp's Windows Manager defined default behaviour.

    # set XWayland
    GDK_BACKEND=x11
	# ** or **
    # set Wayland
    GDK_BACKEND=wayland

If that improves matters, add the setting to [the configuration file](mwp-Configuration.md#cmdopts).

### Gtk Widget whinging

{{ mwp }} used Gtk+-3.0 and a number of no longer maintained components (`gdl`, `champlain`). There are no suitanle Gtk4 replacements for these, so {{ mwp }} remains stuck on Gtk+-3.0.

This means you may see a raft of scary messages on `stderr`, such as:

```
(org.stronnag.mwp:526430): Gdl-CRITICAL **: 17:47:12.509: gdl_dock_item_grip_realize: assertion 'grip->priv->label != NULL' failed

(org.stronnag.mwp:526430): Gtk-CRITICAL **: 17:47:12.555: gtk_widget_get_preferred_height: assertion 'GTK_IS_WIDGET (widget)' failed
```

This is unfixable in the context of {{ mwp }}. See also [this Github discussion]( https://github.com/stronnag/mwptools/discussions/128).
