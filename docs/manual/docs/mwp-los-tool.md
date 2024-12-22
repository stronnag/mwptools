# Line of Sight (LOS) Tool

## Overview

{{ mwp }} provides a LOS tool that establishes whether there is LOS between the observer location (the mwp home icon) and arbitrary points on an {{ inav }} mission. This is may be useful to establish:

* Can the pilot or observer see the aircraft?
* Is there LOS for RC control or video?

## Caveats

There are a number of issues to take into consideration.

* Online DEMs (Digital Elevation Model) vary [significantly](Mission-Elevation-Plot-and-Terrain-Analysis.md/#datum), with implications for accuracy.

{{ mwp }} uses  [Mapzen DEM](https://registry.opendata.aws/terrain-tiles/) data, which improves accuracy (more users  get 30m data) with better accuracy, as well as a significant performance boost and offline usage after the initial data download.

Please be aware of these accuracy / fidelity issues when evaluating the results of any elevation analysis.

## Invocation

!!! note "Legacy Images"
    The images this section are from legacy mwp, however the capability is the same.

LOS is invoked from any waypoint using the right mouse button.

![Menu Options](images/los-menu.png){: width="30%" }

## Line of sight ...

The user can select locations on the mission via a slider and run an analysis. A LOS calculation is performed, a graphical view is shown and a red (no LOS), orange (LOS below a user defined margin) or green (unconditional LOS) line is displayed on the map from the observer (home location) to the chosen location. This may be repeated as required.

## Area LOS

Pressing a modifier key (Shift or Control) while selecting "Line of Sight ..."  will invoke **Area LOS** ;  the calculation is performed automatically with 1% increments of the [naive mission length](#miscellaneous-notes). A set of resulting green/orange/red LOS lines is displayed on the map.

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

The user may repeat the "move slider" / "Point LOS" action as required. The prior terrain plot is removed each time "Point LOS" is selected; the lines on the map are removed when the slider dialog is closed. "Area LOS" may be used to run a continuous analysis from the currently selected location. "Area LOS" may be started / stopped at any point (and Point Analysis invoked at any time when stopped).

When an analysis results in an orange or red LOS line, the first point where the LOS break is detected is shown on the line as a coloured blob. This is apparent in the Area image below.

![Manual LOS](images/los_manual.png)

### Area LOS

This analysis is iterated along the mission path automatically, providing Area coverage for the mission.

![Auto LOS](images/auto-los.png)

The image shows the state after a complete "Area" analysis. While the analysis is running, the slider and "Point LOS" are not sensitive; once the run has completed, these controls are available if the user wishes to investigate further. The user can stop (and restart) Area  using the "Area LOS" / "Stop" button. (Note: in earlier versions, "Area LOS" was called "Auto LOS").

Here, the user has subsequently used "Point LOS" to examine a point in the orange region. As expected, there is very little clearance between the LOS line and the terrain. This is confirmed on the map plot where the "blobs" (immediately to the right of the plot window close button) indicate the point where LOS is compromised.

It is important to note that Area LOS is performed at 1% increments of the [naive mission length](#miscellaneous-notes), it is not contiguous. In the above case, there is a point at 34.1% where there is no LOS.

![Bad LOS](images/fail-los.png)

If you selection the "High Resolution" when running "Area LOS", you get 0.1% increments, which may be used to investigate small segments (it will be slower ... and resource intensive). Here a detailed analysis has been run from 33.6% to 34.6% which captures the instance of complete loss of LOS.

![Auto_no LOS](images/auto-bad-los.png)

Caveat user!

There is also a You Tube video (uses a slightly earlier UI iteration).

<iframe width="768" height="634" src="https://www.youtube.com/embed/EIm8vksK1Pg" title="mwp LOS (Line of Sight) Tool" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

## Local DEMs

mwp uses [Mapzen DEM](https://registry.opendata.aws/terrain-tiles/) SRTM (Shuttle Radar Telemetry Mission) HGT files for all mwp elevation requirements. These are downloaded on demand. No user access key is required.

## Miscellaneous notes

* The Area LOS data is interval sampled. An obstruction could always be in the gap.
* The elevation data does not include obstructions above the terrain (trees, buildings, power lines etc.).
* The mission interpretation is naive.
    - There is no loiter radius
    - The vehicle can turn sharply at way points
    -  There is linear ascent / descent between way points, including from home to WP1 and from RTH to home.
    - JUMPs are executed once.
