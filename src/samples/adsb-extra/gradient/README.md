## Gradient for ADSB altitude display

The tools here are illustrate how mwp scales colours used for altitude display of ADSB contacts.

* Contact colours are based on altitude between 0m and 12000m. Altitudes outside this range are locked to the appropriate end points.
* Altitude is "banded" in 500m bands, giving 25 colours in the range.
* Colours are scaled using an HSV colour space.

### HSV / Altitude scaling

```
altitude is contrained to 0-12000
index = alitude / 500
for HSV, S=80, V=100.
H (scaled to 0 - 1 for 0 - 360° range)
h = 0.05 + 0.75*(alt / 12000)

i.e. h has range 0.05 - 0.85 (18 - 306 in standard 360°  scale)

```

### Tools

#### `read_svg`

Build by the `Makefile`.

```
make
```

`read_svg` generates a set of SVGs for a given model (from the mwp SVG models),

```
./read_svg A3.svg
alt     0, id  0, fill #ff7032
alt   500, id  1, fill #ff9932
...
alt 11500, id 23, fill #ea32ff
alt 12000, id 24, fill #ff32ea
```

It also generates a list of fill colours, e.g. as used by `mkrect.rb` to generate the legend.

#### `mkrect.rb`

`mkrect.rb` takes the output of `read_svg` (read from STDIN) and generates a SVG gradient image. By default this is horizontal.

``` ruby
 ./mkrect.rb --help
mkrect.rb [options]
    -o, --opacity=VAL                opacity (0-1)
    -s, --size=VAL                   dominant size
    -v, --vertical                   orientation
    -?, --help                       Show this message
```
e.g.

```
./read_svg A3.svg  | ./mkrect.rb  > /tmp/hlegend.svg
./read_svg A3.svg  | ./mkrect.rb -v -s 250 -o 0.8 > /tmp/vlegend.svg
```

### Runtime altitude dependent colour coding of SVG models.

In order for user defined ADSB SVG models to be colour coded according to altitude, the following rules apply:

* There are 25 "bands" from 0 to 12000m at 500m intervals
* Both the fill (background) and stroke (foreground) will be updated according to altitude if the SVG is formatted as described below. In particular, if the `id` tag is missing or not recognised, no alternation will be made.

mwp applies the following in generating altitude dependent colour modification.

* Prerequisite: The fill and stroke paths are each defined as follows:
  ```xml
  <path ... fill="..." .../>
  ```
* In order for the background fill to be updated, an attribute `id="mwpbg"` must be provided **before** the `fill` attribute, for example:
  ```xml
  <path id="mwpbg" fill="rgb(255,255,255)"  fill-opacity="1" ... />
   ```
* In order for the foreground stroke to be updated, an attribute `id="mwpfg"` must be provided **before** the `fill` attribute, for example:
  ```xml
  <path id="mwpfg" fill="rgb(0%,0%,0%)" ... />
   ```
* If the required `id` is present, the `fill` attribute will be updated as:
  - For `id="mwpbg"`, the fill (background) is set to an altitude band colour.
  - For `id="mwpfg"`, the fill (outline) is set to white if the altitude is > 6000m.

Note that mwp processes each SVG at startup and caches internally the image generated from such transformations. The aircraft icons are updated at runtime when an aircraft moves between bands.

## Resizing and Automation

The script `resize_icons.sh` (in the parent directory) will resize a set of SVGs.
Unfortunately, this will remove any `id="mwpfg"` or `id="mwpbg"` attributes (and any `mwp:xalign` and `mwp:yalign` attributes). These will have to be reapplied.
