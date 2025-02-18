
## Work flow for ADSB icons:

```
# Tools area
$ cd src/samples/adsb-extra/
#
# Make the fixup tool
$ make fixup-svg
#
# create a work space
$ mkdir /tmp/icons
#
# copy and resize the ADSB icons
$ cp ../../../data/pixmaps/adsb/*.svg  /tmp/icons/
# Now resize ....
$ ./resize-icons.sh -f 2.0 /tmp/icons/*.svg
rsvg-convert -w 44.0 -h 44.0 -a -f svg -o /tmp/icons/A0.svg /tmp/icons/_A0.svg
...
rsvg-convert -w 30.0 -h 30.0 -a -f svg -o /tmp/icons/C3.svg /tmp/icons/_C3.svg
For ADSB symbols, you may have to (re)apply  'id="mwpfg"' and 'id="mwpbg"' attributes to the resized icons : see gradient/README.md
For other symbols, you may have to (re)apply 'mwp:xalign' or 'mwp:yalign' attributes to the resized icons
#
# Add the gradient 'id's back ...
$ ./fixup-svg --gradients /tmp/icons/*.svg
#
# copy the files over ....
$ cp /tmp/icons/*.svg ~/.config/mwp/pixmaps/adsb/
```

# Work flow for GCS or other icon

```
$ ./fixup-svg --yalign 1  /tmp/valk1.svg
/home/jrh/.config/mwp/pixmaps/valk1.svg does not have the 'width' and/or 'height' attribute
```
... need to make the svg "screen" friendly ...

```
$ rsvg-convert -f svg -a -w 44 -o /tmp/valk1.svg /tmp/valk1.svg
# Now set the aligmnet to the bottom, centred
$ ./fixup-svg --yalign 1  /tmp/valk1.svg
$ cp /tmp/valk1.svg ~/.config/mwp/pixmaps
$ cd ~/.config/mwp/pixmaps
$ ln -sf valk1.svg gcs.svg
```

With pointy labels ... because everyone likes pointy labels.

![pointy!](icons..png)
