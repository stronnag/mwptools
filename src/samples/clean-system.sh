#!/bin/bash
[ $(id -u) -eq  0 ] || { echo "Please run $0 as root"; exit;}
rm -f /usr/bin/{cf-cli,cf-cli-ui,mspsim,mwp,mwp_ath}
rm -f /usr/bin/{qproxy,switchedit,ublox-cli,ublox-geo,replay_bbox_ltm.rb,pidedit}
rm -rf /usr/share/{cf-cli,cf-cli-ui,mspsim,mwp,mwp_ath,pidedit}
rm -rf /usr/share/applications/{mspsim,mwp,pidedit,switchedit}.desktop
rm -rf /usr/share/{qproxy,switchedit,ublox-cli,ublox-geo,replay_bbox_ltm.rb}
if [ -e /usr/share/glib-2.0/schemas/org.mwptools.planner.gschema.xml ] ; then
  rm -f /usr/share/glib-2.0/schemas/org.mwptools.planner.gschema.xml
  glib-compile-schemas /usr/share/glib-2.0/schemas
fi
