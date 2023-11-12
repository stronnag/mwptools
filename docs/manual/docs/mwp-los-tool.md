# Line of Sight (LOS) Tool

## Overview

{{ mwp }} provides a LOS tool that establishes whether there is LOS between the observer location (the mwp home icon) and arbitrary points on an {{ inav }} mission. This is may be useful to establish:

* Can the pilot or observer see the aircraft?
* Is there LOS for RC control or video?

## Caveats

There are a number of issues to take into consideration.

* Online DEMs (Digital Elevation Model) vary [significantly](Mission-Elevation-Plot-and-Terrain-Analysis.md/#datum), with implications for accuracy.
* Bing Elevations (BE) limits a single query to 1024 points, the data is 30m grid (best case). BE is actually more generous than most online sources.
* The mwp uses the lesser of (mission length / 30) (metres) or 1024 points.

Please be aware of these accuracy / fidelity issues when evaluating the results of any elevation analysis.

## Invocation

LOS is invoked from any waypoint using the right mouse button.

![Menu Options](images/los-menu.png){: width="30%" }

## Line of sight ...

The user can select locations on the mission via a slider and run an analysis. A LOS calculation is performed, a graphical view is shown and a red (no LOS), orange (LOS below a user defined margin) or green (unconditional LOS) line is displayed on the map from the observer (home location) to the chosen location. This may be repeated as required.

## Auto LOS

If the user has [applied their own Bing API key](#user-bing-key), then pressing a modifier key (Shift or Control) while selecting "Line of Sight ..."  will invoke **Auto LOS** ;  the calculation is performed automatically with 1% increments of the [naive mission length](#miscellaneous-notes). A set of resulting green/orange/red LOS lines is displayed on the map.

Note that both options are available from the LOS analysis window; the modifier option is merely a convenience.

## Examples

When the LOS slider is displayed, the only UI actions available are:

* Scroll the map
* Zoom the map
* Change the map product

This restriction means that the mission cannot be changed while a LOS Analysis is being performed.

### Manual LOS Analysis

In the image below, the user has selected "Line of Sight ..." from the right mouse menu at WP9. The slider is positioned appropriate to WP9. Note that if the mission contains JUMP WPs, these are executed once only (regardless of the mission setting). This is why the slider might appear less advanced compared to the mission length if the JUMP is ignored. The user can reposition the WP using the slider (or the start / end buttons).

When "Point LOS" is clicked, the LOS is calculated between planned home (brown icon, lower left) and the red "⨁" "Point of Interest" (POI) icon. This is displayed as a terrain plot with the LOS line superimposed over the terrain elevation. The line is red as there is no LOS (and it would be green where there is LOS). A red "dot-dash" is also displayed on the map. If a margin is specified, then LOS lines with clearance between the terrain and the margin value are shown in orange.

The user may repeat the "move slider" / "Point LOS" action as required. The prior terrain plot is removed each time "Point LOS" is selected; the lines on the map are removed when the slider dialog is closed. "Auto LOS" may be used to run a continuous analysis from the currently selected location. "Auto LOS" may be started / stopped at any point (and Point Analysis invoked at any time when stopped).

When an analysis results in an orange or red LOS line, the first point where the LOS break is detected is shown on the line as a coloured blob. This is apparent in the Auto image below.

![Manual LOS](images/los_manual.png)

### Auto LOS

If the user has specified a [user supplied Bing API key](#user-bing-api-key), then an Auto LOS analysis can be run. The analysis is iterated along the mission path automatically.

![Auto LOS](images/auto-los.png)

The image shows the state after a complete "Auto" analysis. While the analysis is running, the slider and "Point LOS" are not sensitive; once the run has completed, these controls are available if the user wishes to investigate further. The user can stop (and restart) Auto  using the "Auto LOS" / "Stop" button.

Here, the user has subsequently used "Point LOS" to examine a point in the orange region. As expected, there is very little clearance between the LOS line and the terrain. This is confirmed on the map plot where the "blobs" (immediately to the right of the plot window close button) indicate the point where LOS is compromised.

It is important to note that Auto LOS is performed at 1% increments of the [naive mission length](#miscellaneous-notes), it is not contiguous. In the above case, there is a point at 34.1% where there is no LOS.

![Bad LOS](images/fail-los.png)

If you press a modifier (Shift or Control) while invoking "Auto LOS", you get 0.1% increments, which may be used to investigate small segments (it will be slow ... and resource intensive). Here a detailed analysis has been run from 33.6% to 34.6% which captures the instance of complete loss of LOS.

![Auto_no LOS](images/auto-bad-los.png)


Caveat user!

There is also a You Tube video (uses a slightly earlier UI iteration).

<iframe width="768" height="634" src="https://www.youtube.com/embed/EIm8vksK1Pg" title="mwp LOS (Line of Sight) Tool" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

## User Bing API Key

In the same way that the INAV Configurator requires the user to have their own Bing API key, this is also required for the [Auto LOS](#auto-los) option. Details on now to obtain a key can be found in the [INAV Configurator README](https://github.com/iNavFlight/inav-configurator#how-to-get-the-bing-maps-api-key).

The user's Bing API key should be added to the user's `$HOME/.config/mwp/cmdopts` [file](mwp-Configuration.md#cmdopts), for example:

    #--debug-flags 20
    --dont-maximise

    MWP_BLACK_TILE=/home/jrh/.config/mwp/mars.png
    MWP_TIME_FMT=%T.%f
    MWP_BING_KEY=Axxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

This requirement is to help prevent the generic application API key exceeding usage limits. Using your own key will help ensure the availability of Bing map products for all users.

## Miscellaneous notes

* The auto play output may pause due to network delay / throttling of Bing elevation data.
* These may more visible drawing latency on Xlib (vice Wayland).
* The auto play data is interval sampled. An obstruction could always be in the gap.
* The elevation data does not include obstructions above the terrain (trees, buildings, power lines etc.).
* The mission interpretation is naive.
    - There is no loiter radius
    - The vehicle can turn sharply at way points
    -  There is linear ascent / descent between way points, including from home to WP1 and from RTH to home.
    - JUMPs are executed once.
