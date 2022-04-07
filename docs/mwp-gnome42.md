# mwp and GNOME 42 (and later)

## Description

GNOME 42 and later (on Wayland) provide patchy support for some of the
legacy libraries used by mwp. This *may* result in some issues, which
you may see in system messages if you run mwp from the CLI.

These issues, if any, will also depend on the graphics card e.g. none on
NVidia/nouveau, minor on newish Intel, possibly major on older Intel,
minor / none on software rendering (VM including WSL/g).

mwp is defenceless here; it's entirely dependent on the behaviour of
the distro's system libraries.

## Mitigation

Add the following to $HOME/.config/mwp/cmdopts

```
GDK_BACKEND=x11
```

e.g. paste the following in a terminal.

```
if ! grep -e ^GDK_BACKEND=x11 ~/.config/mwp/cmdopts ; then
  mkdir -p ~/.config/mwp
  echo "GDK_BACKEND=x11" >> ~/.config/mwp/cmdopts
fi
```
