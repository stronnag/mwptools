# Miscellaneous UI Elements

## Preferences

The "Edit > Preferences" menu provides a UI for some `gsetting` / `dconf` [settings](mwp-Configuration.md). The settings here are applied immediately if 'Apply' is clicked.

### General Preferences

![genprefs](images/ui-prefs-1.png){: width="50%" }

### Units Preferences

![unitsprefs](images/ui-prefs-2.png){: width="50%" }

Unit preferences should be instantly reflected in the UI when 'Apply' is clicked.

### Favourite Places

{{ mwp }} maintains a list of favourite places, from "View > Centre on Location" menu item.

![places](images/ui-place-chooser.png){: width="30%" }

The "Place" combo menu holds all places defined in `~/.config/mwp/places` (see the [configuration reference](mwp-Configuration.md)).

For convenience, clicking the 'Editor ...' button will load the "Places Editor".

![placesedit](images/places-editor-menu.png){: width="30%" }

* New items are added with the **+** button.
* Locations can be edited clicking the "Document Edit" icon at the end of the row.
  ![placesedit](images/places-editor-1.png){: width="30%" }

* The context (right mouse button) menu:
    * Zoom to location : Zooms to the place
	* Set location from current view : Sets the location to the centre of the current map view
	* Delete location : Deletes the location without question.
* **OK** Saves the locations to `~/.config/mwp/places`
* Closing using the window manager **X** icon closes without saving.

## Useful Shortcuts

* Control-D : Enters distance measure mode. Click on the map to add more points to measure distance along a path. Press Control-D again to get the distance, with an option to continue to add points. The points may also be dragged.

![measure](images/measure.png){: width="30%" }

In the image, we are measuring the distance between the take off home (brown icon) and the landing home (orange icon); the distance markers are the black/white circles. Ctrl-D has been pressed a second time to display the result.

* Control L : Control-Shift L : Copy the pointer location to the clip board (Ctrl-L, decimal degrees, Ctrl-Shift-L formatted).

## Keyboard Shortcuts

### Menu and Replay

![shortcuts00](images/sc00.png){: width="60%" }

### Map and Tools

![shortcuts01](images/sc01.png){: width="60%" }
