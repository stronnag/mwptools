
subdir('survey')

getinfo = files('getinfo.sh')
mwp_v_args = []
if pointy_labels
  if extra_vapi != ''
    mwp_v_args += ['--vapidir' , extra_vapi]
  endif
  mwp_v_args += '--define=SHUMATE_USE_ALIGN'
endif

mwpvers_h = custom_target(
    '_mwpvers.h',
    output : '_mwpvers.h',
    command : ['sh', getinfo, '@OUTPUT@'],
)

libmwpvers = static_library('mwpvers', ['_mwpvers.c', mwpvers_h],
			     include_directories :  include_directories('.','../','../../')
			   )

mwpsrcs = files('mwp-about.vala', 'mwp-ah_widget.vala',
                'mwp-application.vala', 'mwp-arm_processing.vala',
                'mwp-async-dem-dl.vala', 'mwp-audio.vala', 'mwp-batt-misc.vala',
                'mwp-bb_dialog.vala', 'mwp-clioptions.vala', 'mwp-clipboard.vala',
                'mwp-combox-compat.vala', 'mwp-craft.vala', 'mwp-crsf_processing.vala',
                'mwp-dbus.vala', 'mwp-deltadialog.vala', 'mwp-dem-manager.vala',
                'mwp-dem-reader.vala', 'mwp-dirn.vala', 'mwp-dnd.vala',
                'mwp-enums.vala', 'mwp-etx_dialog.vala', 'mwp-filechooser.vala',
                'mwp-filetypes.vala', 'mwp-flight-misc.vala', 'mwp-flight_view.vala',
                'mwp-flysky.vala', 'mwp-flysky_processing.vala', 'mwp-followme.vala',
                'mwp-forwarder.vala', 'mwp-frsky_processing.vala', 'mwp-fwaplot.vala',
                'mwp-gcs_icon.vala', 'mwp-geninfo.vala', 'mwp-genoverlay.vala',
                'mwp-geozedit.vala', 'mwp-geozonemgr.vala', 'mwp-get_places.vala',
                'mwp-gst-devmon.vala', 'mwp-gstdev.vala', 'mwp-gzutils.vala',
                'mwp-handle_mspmsg.vala', 'mwp-handle_serial.vala',
                'mwp-helpers.vala', 'mwp-home_point.vala', 'mwp-iparser.vala',
                'mwp-js_dialog.vala', 'mwp-kmlovly.vala', 'mwp-kmlwriter.vala',
                'mwp-locwindow.vala', 'mwp-log_runner.vala', 'mwp-logger.vala',
                'mwp-los-analysis.vala', 'mwp-ltm_message.vala', 'mwp-main.vala',
                'mwp-map_seeder.vala', 'mwp-mapmanager.vala', 'mwp-mapsources.vala',
                'mwp-maputils.vala', 'mwp-marker.vala', 'mwp-mavlink_msg.vala',
                'mwp-mdialog.vala', 'mwp-measure.vala', 'mwp-miscdropdowns.vala',
                'mwp-mission-preview.vala', 'mwp-mission.vala',
                'mwp-mission_graphics.vala', 'mwp-mission_manager.vala',
                'mwp-mission_tote.vala', 'mwp-mm_support.vala', 'mwp-msp_radar.vala',
                'mwp-odo.vala', 'mwp-paned.vala', 'mwp-permids.vala',
                'mwp-prefs.vala', 'mwp-preview-mission.vala', 'mwp-radar-cache.vala',
                'mwp-radar_decoders.vala', 'mwp-radar_list.vala',
                'mwp-radar_map_support.vala', 'mwp-range-circles.vala',
                'mwp-raw_dialog.vala', 'mwp-replay.vala', 'mwp-rssi_box.vala',
                'mwp-safehomes.vala', 'mwp-sbs-decoder.vala', 'mwp-scwindow.vala',
                'mwp-serial_manager.vala', 'mwp-settings.vala',
                'mwp-shape_dialog.vala', 'mwp-shedit.vala',
                'mwp-speedalt_dialog.vala',
                'mwp-sticks.vala', 'mwp-telem-tracker.vala',
                'mwp-terminal-funcs.vala', 'mwp-terrain_analysis.vala',
                'mwp-tileseeder_window.vala', 'mwp-touch-support.vala',
                'mwp-tts.vala', 'mwp-units.vala',
                'mwp-upower.vala', 'mwp-vario.vala', 'mwp-video-manager.vala',
                'mwp-voltage.vala', 'mwp-window.vala', 'mwp-wp_io_handler.vala',
                'mwp-wpeditmgr.vala', 'mwp-wpeditwindow.vala', 'mwp-xdg_notify.vala',
                'mwp-combox.vala',
                'mwp-gpsstats.vala',
                'mwp-gzmisc.vala',
                'mwp-idler.vala',
                'speech_wrapper.c',
                'mwp-windest.vala',
                'mwp-assist_now.vala',
                'mwp-label.vala',
                'mwp-svgreader.vala'
               )

mwpdeps = [deps,
	   dependency('gtk4', version: '>=4.14'),
           dependency ('libadwaita-1', version: '>= 1.5'),
	   dependency('glib-2.0'),
           soupdep,
           dependency('libxml-2.0'),
           dependency('gio-2.0'),
           dependency('shumate-1.0'),
           dependency('gstreamer-1.0'),
           dependency('json-glib-1.0'),
           dependency('libsecret-1'),
           meson.get_compiler('vala').find_library('posix'),
           meson.get_compiler('vala').find_library('linux'),
          ]

if host_machine.system() != 'windows'
  mwpdeps += dependency('vte-2.91-gtk4')
endif

if host_machine.system() != 'linux'
  mwpsrcs += files('serial_watcher.vala')
endif

mwpsrcs += svyfiles

protoc = dependency('libprotobuf-c', required: false)
if protoc.found()
  libdir=protoc.get_variable(default_value : '', pkgconfig : 'libdir')
  protoc =  meson.get_compiler('c').find_library('protobuf-c', dirs: libdir)
  mwpsrcs += files('readsb.pb-c.c', 'decode_readsb.c', 'decode_readsb.c')
  mwpdeps += protoc
  mwp_v_args += ['--vapidir', meson.current_source_dir(), '--pkg', 'decode_readsb', '--define=PROTOC' ]
endif


# for BSD etc.
mwp_c_args = []

if paho.found()
  mwp_v_args += '--define=MQTT'
  mwp_v_args += '--define=MQTT_PAHO'
  mwpdeps += paho
  mwpsrcs += files('mwp-mqtt_support.vala', 'mwp-mqtt_common.vala')
else
  mosquitto = dependency('libmosquitto', required: false)
  if mosquitto.found()
    libdir=mosquitto.get_variable(default_value : '', pkgconfig : 'libdir')
    mosquitto = meson.get_compiler('c').find_library('mosquitto', dirs: libdir)
    mwp_v_args += '--define=MQTT'
    mwp_v_args += '--define=MQTT_MOSQUITTO'
    mwp_v_args += ['--pkg', 'libmosquitto']
    mwpdeps +=  mosquitto
    mwpsrcs += files('mwp-mqtt_support.vala', 'mwp-mqtt_common.vala')
  endif
endif

if xopts.length() > 0
  mwpdeps += dependency('gmodule-2.0')
  foreach x : xopts
    mwp_v_args += '--define='+x
    mwp_c_args += '-D'+x
  endforeach
endif

if host_machine.system() == 'windows'
#  mwp_v_args += '-X'
#  mwp_v_args += '-mwindows'
  windows = import('windows')
  mwpsrcs += windows.compile_resources('winres.rc')
endif

if paho.found()
  mwp_v_args += ['--pkg', 'paho_wrapper']
endif

soup3 = dependency('libsoup-3.0', version: '>=3.4', required: false)
if soup3.found()
  dopts += '--define=MODERN_SOUP'
endif

common_inc_dir += include_directories('.')
