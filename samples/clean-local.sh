#!/bin/bash

rm -f ~/bin/{cf-cli,cf-cli-ui,mspsim,mwp,mwp_ath}
rm -f ~/bin/{qproxy,switchedit,ublox-cli,ublox-geo,replay_bbox_ltm.rb}
rm -rf ~/.local/share/{cf-cli,cf-cli-ui,mspsim,mwp,mwp_ath}
rm -rf ~/.local/share/{qproxy,switchedit,ublox-cli,ublox-geo,replay_bbox_ltm.rb}
rm -f ~/.local/share/glib-2.0/schemas/org.mwptools.planner.gschema.xml
rm -f ~/.local/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas ~/.local/share/glib-2.0/schemas >/dev/null

[ -n "$XDG_DATA_DIRS" ] && echo "Consider removing the definition of XDG_DATA_DIRS"
