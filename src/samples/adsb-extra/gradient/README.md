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

`read_svg` generates a set if SVGs for a given model (from the mwp SVG models),

```
./read_svg A3.svg
alt     0, id  0, fill #ff7032
alt   500, id  1, fill #ff9932
...
alt 11500, id 23, fill #ea32ff
alt 12000, id 24, fill #ff32ea
```

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
