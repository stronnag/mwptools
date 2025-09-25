# Side Bar Concepts and Usage

## Side Bar Overview

The **Side Bar**, items 4 and 6 in the main window guide provides an area for optional widgets.

![main](images/main-window.avif){: width="100%" }

A very simple, bespoke panel comprising embedded panes on a grid has been implemented. Opinionated settings that work in both "Standard" and "FPV View" modes are provided. Configuration is [described below](#side-bar-configuration).

<iframe width="560" height="315" src="https://www.youtube.com/embed/pxWqm9QUlRk?si=An2vccYD7wrFPRfj" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

The main sidebar (dock) controls are shown below. Please note some of these images are from the legacy version of {{ mwp }}:

## Side Bar Items (Dockets)

The following items are provided.

### Artificial Horizon

![dockah](images/dock_ah.avif){: width="30%" }

### Direction View

![dockdir](images/dock_dirn.avif){: width="15%" }

### Flight View

![dockdir](images/dock_fv.avif){: width="33%" }

### RSSI / LQ Status

![dockdir](images/dock_radio.avif){: width="15%" }

### Battery Monitor

![dockdir](images/dock_batt.avif){: width="30%" }

### Vario View

![dockdir](images/dock_vario.avif){: width="25%" }
![dockdir](images/dock_vario_l.avif){: width="25%" }
![dockdir](images/dock_vario_d.avif){: width="25%" }

### Wind Estimator (new / Gtk4)

![dockwind](images/panel-vas.avif){: width="25%" }

## Side Bar Configuration

The configuration may be user defined by a simple text file `~/.config/mwp/.panel.conf`.

Note that everything is defined in terms of a standard (vertical) panel. When in FPV Mode (horizontal panel), rows are columns are automatically transposed.

The default is:

```
# mwp panel v2
# name, row, col, width, height, span, mode
ahi,0,0,200,200,2,3
rssi,1,0,-1,-1,1,3
vario,1,1,-1,-1,1,3
wind,2,0,-1,-1,1,1
dirn,2,1,-1,-1,1,1
flight,3,0,-1,-1,2,3
volts,4,0,-1,-1,2,3
```

where:

* `rows` and `columns` are 0 indexed
* `span` describes the number of rows (or columns) that widget a spans, allowing "large" items.
* The combination of `columns` and the sum of `spans` should be consistent across all rows to avoid blank items (see compressed example below).
* `width` and `height` is only required for the `ahi`; otherwise `-1` means "best fit"
* `mode` is a bit mask defining whether a widget is shown when vertical (1) and horizontal (2) (so 3 means both).

No graphical means is currently available to edit the panel, it has to be done by a text editor.

### Compressed example

This FreeBSD VM has a quite restricted screen size. In order to have a useful panel, it was optimal to have three columns, with spans adjusted for consistency. This works in both modes:

```
# mwp panel v2
# 3 row example
# name, row, col, width, height, span, mode
rssi,0,0,-1,-1,1,3
ahi,0,1,100,100,1,3
vario,0,2,-1,-1,1,3
wind,2,0,-1,-1,2,1
dirn,2,2,-1,-1,1,1
flight,3,0,-1,-1,3,3
volts,4,0,-1,-1,3,3
```

![freebsd vertical](images/fpvmode/freebsd-std-mode.avif)

![freebsd horizontal](images/fpvmode/freebsd-fpv-mode.avif)


### Available Widgets

The available panel widgets are named as:

| Name | Usage |
| ---- | ---- |
| `ahi` | Artificial horizon |
| `dirn` | Direction comparison |
| `flight` | "Flight View" Position / Velocity / Satellites etc, |
| `volts` | Battery information |
| `vario` | Vario indicator |
|  `wind` | Wind Estimator (BBL replay only) |

No other legacy widgets have been migrated.
