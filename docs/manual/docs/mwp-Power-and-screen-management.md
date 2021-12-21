# Power and screen management

There are a number of ways of managing the screen (inhibit screen saver etc.)

* Use an external screen-saver manager such as [caffeine](https://extensions.gnome.org/extension/517/caffeine/)

* Use the legacy {{ mwp }}  settings options, for example:
```
org.mwptools.planner atexit 'gsettings set org.gnome.settings-daemon.plugins.power idle-dim true'
org.mwptools.planner atstart 'gsettings set org.gnome.settings-daemon.plugins.power idle-dim false'
```
* Allow {{ mwp }} to manage screen and power settings, controlled by a setting:

```
gsettings set org.mwptools.planner manage-power true
```

In the first two cases, the setting is somewhat coarse, either requiring the user to click on something and applying to the whole {{ mwp }} session.

The final case applies only when {{ mwp }} is receiving push telemetry (LTM, Mavlink, MQTT). Inhibiting IDLE and SUSPEND is performed using the GTK inhibit() API and will thus work with most window managers.
