# Colours

mwp sets line and fill characteristics for GeoZones according to the zone's `type` and `action`.

The default values are set as:

| Type      |  Action  | Line      | Fill     |
| ----------| ---------| ----------| -------- |
| Exclusive |  None    | red 4 4   |          |
| Exclusive |  Avoid   | red 4     | red      |
| Exclusive |  PosHold | red 10    | red      |
| Exclusive |  RTH     | red 10    | red      |
| Inclusive |  None    | green 4 4 |          |
| Inclusive |  Avoid   | green 4   |          |
| Inclusive |  PosHold | green 10  |          |
| Inclusive |  RTH     | green 10  | green    |

The values after the line colour are line width and optional dash width.

The default colours are those suggested by the user who requested that mwp support GeoZones.

Specifically, the default "red" and "green" colours have some opacity:

| Type | Value |
| ---- | ----- |
| Line red | `rgba(255,0,0,0.625)` |
| Fill red | `rgba(255,0,0,0.125)` |
| Line green | `rgba(0,255,0,0.625)` |
| Fill green | `rgba(0,255,0,0.125)` |

Where line width is greater than 10, the opacity is reduced by 20% to satisfy the author's aesthetic opinion.

## User definition

The user may specify their own colours by creating a _pipe separated_ file, `$HOME/.config/mwp/zone_colours`. This is a text file of the format:


    type|action|line_colour|line_width|line_dash|fill_colour


### User definition fields:

**Type:** The zone type as an integer (0-1)

**Action**: The zone action as an integer (0-3).

**Line Colour**: see below for colour formats

**Line Width**: In pixels, as an integer

**Line Dash**: In pixels, as an integer; the line will alternate on/off using this value.

**Fill Colour**: see below for colour formats

### Colour defintion

Colours may be defined as:

* A standard name (taken from the [X11 "rgb.txt"](https://en.wikipedia.org/wiki/X11_color_names) file) ; or

* A hexadecimal value in the form `#rrggbb` or `#rrggbbaa` ; or
* A RGB colour in the form `rgb(r,g,b)` (In this case the colour will have full opacity); or
* A RGBA colour in the form `rgba(r,g,b,a)`

Where `r`, `g`, `b` and `a` are respectively the red, green, blue and alpha colour values. In the latter two cases, `r`, `g`, and `b` are either integers in the range 0 to 255 or percentage values in the range 0% to 100%, and `a` is a floating point value in the range 0 to 1.

If the alpha component is not specified then it is set to be fully opaque.

For "standard X11 names", an opacity may be defined by appending a floating point value in the range 0 to 1.0 to the name, separated by a semi-colon, for example `steelblue;0.8`

### Default settings as `zone_colours` file

The default settings can bee represented in a `zone_colours` file as:


    0|0|rgba(255,0,0,0.625)|4|4|
    0|1|rgba(255,0,0,0.625)|4|0|rgba(255,0,0,0.125)
	0|2|rgba(255,0,0,0.625)|10|0|rgba(255,0,0,0.125)
	0|3|rgba(255,0,0,0.625)|10|0|rgba(255,0,0,0.125)
	1|0|rgba(0,255,0,0.625)|4|4|
	1|1|rgba(0,255,0,0.625)|4|0|
	1|2|rgba(0,255,0,0.625)|10|0|
	1|3|rgba(0,255,0,0.625)|10|0|rgba(0,255,0,0.125)

If a line cannot be parsed, an error will the logged, giving the offending line number(s).
Blank lines and comment lines (starting with `#` or `;`) are ignored.

Please also note that floating point values must be specified with a _point_ (`.`), even when the locale customary format would use _comma_ (`,`).

Alternate colour formats for the first line are:

    0|0|red;0.625|4|4|
    0|0|#ff0000a0|4|4|
