# Side Bar Concepts and Usage

## Side Bar Overview

The **Side Bar**, items 4 and 6 in the main window guide provides an area for optional widgets.

![main](images/main-window.png){: width="100%" }

The main dock controls are shown below. Please note these images are from the legacy version of {{ mwp }}.:

## Side Bar Items (Dockets)

The following items are provided.

### Artificial Horizon

![dockah](images/dock_ah.png){: width="30%" }

### Direction View

![dockdir](images/dock_dirn.png){: width="15%" }

### Flight View

![dockdir](images/dock_fv.png){: width="33%" }

### RSSI / LQ Status

![dockdir](images/dock_radio.png){: width="15%" }

### Battery Monitor

![dockdir](images/dock_batt.png){: width="30%" }

### Vario View

![dockdir](images/dock_vario.png){: width="25%" }
![dockdir](images/dock_vario_l.png){: width="25%" }
![dockdir](images/dock_vario_d.png){: width="25%" }

### Wind Estimator (new / Gtk4)

![dockwind](images/panel-vas.png){: width="25%" }

## Side Bar Configuration


A very simple, bespoke panel comprising embedded resizeable panes has been implemented. The configuration may be user defined by a simple text file `~/.config/mwp/panel.conf`.

* The panel consists for four vertical panels
* The top panel can hold three horizontal panes
* The other panels can hold two horizontal panes.

Each entry is defined by a comma separated line defining the panel widget name, the row (0-3) and the column (0-2) and an optional minimum size (only required for the artificial horizon). The default panel is defined (in the absence of a configuration file) as:

```
# default widgets
ahi,0,1,100
rssi, 1, 0
dirn, 1, 1
flight, 2, 0
volts, 3, 0
```

Which appears as:
![mwp4-panel-0](images/mwp4-panel-0.png)

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

So using the following `~/.config/mwp/panel.conf`

```
# default + vario + wind widgets
ahi, 0, 1, 100
vario,0,2
rssi, 0, 0
wind, 1, 0
dirn, 1, 1
flight, 2, 0
volts, 3, 0
```

would appear as:
![mwp4-panel-1](images/mwp4-panel-1.png)
