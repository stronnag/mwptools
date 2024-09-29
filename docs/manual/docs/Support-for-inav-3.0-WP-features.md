# mwp and INAV 3.0 Mission Updates

## Overview

INAV 3.0 adds a couple of changes to INAV mission planning:

* Absolute WP altitudes
* Land WP ground elevation setting

### Absolute WP altitudes

For Multiwii and INAV prior to 3.0, waypoint altitudes were always relative to the arming location. If you always fly in a flat area, or always arm at the same point, this wasn't really an issue; you could always use [mwp's terrain analysis](Mission-Elevation-Plot-and-Terrain-Analysis.md) to check that you'd clear any obstructions.

However, if you armed some (vertical) distance from the arming point assumed when the plan was created, the absolute, (AMSL) elevation of the WP would differ by the ground difference between the assumed arming point at planning time and the actual arming point at take off. In the worst case (arming at an 'zero' absolute elevation well below the 'assumed at planning time' location), this could result in automated flight into terrain, which is generally undesirable.

Absolute mission altitudes addresses this issue, as the AMSL elevation of the WP is fixed and does not depend on arming location.

### Land WP ground elevation setting

A similar issue existed prior to INAV 3.0 for the LAND WP; the initial implementation assumed that the LAND WP site ground elevation was at approximately the same ground elevation as the arming location. INAV computes landing behaviour based on relative altitude from home; if the actual LAND site was lower than home, then the descent would be slow; if it was higher, then slowdown might not occur and there would be a hard landing (for MR). For FW the final approach and motor-off would be sub-optimal.

The required land elevation uses the `P2` WP parameter, **in metres.**

* If LAND is a relative altitude WP, then this is the altitude difference between the assumed home and the LAND location.
* If LAND is an absolute altitude WP, then this is the absolute (AMSL) altitude of the LAND location.

## mwp support for 3.0 features

**mwp** supports the new feature in the WP Editor and Terrain Analysis.


### Terrain Analysis

[mwp's terrain analysis](Mission-Elevation-Plot-and-Terrain-Analysis.md) function has been upgraded to handle INAV 3.0 features (Relative / Absolute Elevations, Land Ground Elevation). The [mwp terrain analysis article](Mission-Elevation-Plot-and-Terrain-Analysis.md) describes the new analysis tool.

In the image below, the dialogue has been enhanced to allow selection of the altitude mode and adjustment of LAND elevation. The orange graph line shows the generated mission with a 40m clearance of all obstacles.

![Terrain Analysis](images/mwp-inav-3_5.png){: width="80%" }

The user can select the following altitude modes:

![Terrain Analysis](images/mwp-inav-3_6.png){: width="30%" }

* Mission - use the altitude mode from the mission
* Relative to home
* Absolute (AMSL).

## Further reading

The [INAV wiki](https://github.com/iNavFlight/inav/wiki/MSP-Navigation-Messages) describes WP mission parameters in some detail.

Discussion of the meaning of ["sea level"](Mission-Elevation-Plot-and-Terrain-Analysis.md#datum). It's confusing.
