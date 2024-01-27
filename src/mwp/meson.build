
getinfo = files('getinfo.sh')


mwpvers_h = custom_target(
    '_mwpvers.h',
    output : '_mwpvers.h',
    command : [getinfo, '@OUTPUT@'],
)

libmwpvers = static_library('mwpvers', ['_mwpvers.c', mwpvers_h],
			     include_directories :  include_directories('.','../','../../')
			  )

mwpsrcs = files('mwp.vala', 'liststore.vala', 'mwp_markers.vala',
		'mwp_craft.vala', 'settings.vala', 'dialogs.vala', 'mapsources.vala',
		'local_geo.vala', 'logger.vala', 'speech_wrapper.c', 'mwp-replay.vala',
		'map_seeder.vala', 'mwp-layout.vala', 'iparser.vala', 'mwp_bbox.vala',
		'ah_widget.vala', 'get_places.vala', 'mission.vala',
		'mwp_dbus.vala', 'name_type_map.vala', 'mwp_pe_support.vala',
		'kmlovly.vala', 'mwp_upower.vala', 'replicate_wp.vala',
		'mwp-mission-preview.vala', 'mwp-radar_list.vala',
		'mwp_safehomes.vala', 'mwp_otx.vala',
		'mwp_xdg_notify.vala', 'mwp_elevations.vala', 'mdialog.vala',
		'mm_support.vala', 'flysky.vala', 'gst-devmon.vala',
		'gst-video-player.vala', 'gst-audio-player.vala',
		'mwp_gcs_icon.vala', 'mwp_preview_image.vala',
		'mwp-sbs-decoder.vala', 'mwp-helpers.vala',
		'mwp-sticks.vala', 'mwp_splash.vala', 'wpeditpopover.vala',
		'mwp-measure.vala', 'mwp_rraw.vala', 'mwp_followme_ph.vala',
                'mwp_telem-tracker.vala', 'mwp-forwarder.vala',
                'mwp-los-analysis.vala', 'dem-reader.vala', 'mwp-async-dem-dl.vala',
                'geozreader.vala', 'genoverlay.vala'
               )

ublxguisrc = files('settings.vala',  'mapsources.vala')

apuisrcs = files('settings.vala',  'mapsources.vala', 'mission.vala')

mwp_v_args = ['--vapidir', vapi_dir, '--pkg', 'mwpfuncs']

mwpdeps = [deps,
	   dependency('gtk+-3.0'),
	   dependency('glib-2.0'),
           dependency('atk'),
           dependency('clutter-1.0'),
           dependency('champlain-gtk-0.12'),
           dependency('champlain-0.12'),
           soupdep,
           dependency('libxml-2.0'),
           dependency('gio-2.0'),
           dependency('clutter-gtk-1.0'),
           dependency('gdl-3.0'),
           dependency('pango'),
           dependency('cairo'),
           dependency('gstreamer-1.0'),
           dependency('gstreamer-pbutils-1.0'),
           dependency('vte-2.91'),
           meson.get_compiler('vala').find_library('posix'),
           meson.get_compiler('vala').find_library('linux'),
          ]

# for BSD etc.
ldirs = ['/usr/lib', '/usr/local/lib']
mwp_c_args = []

paho = meson.get_compiler('c').find_library('paho-mqtt3cs', dirs: ldirs, required: false)

if paho.found()
  mwp_v_args += '--define=MQTT'
  mwp_v_args += '--define=MQTT_PAHO'
  mwpdeps += paho
  mwpsrcs += files('paho_wrapper.c', 'mwp_mqtt_common.vala')
else
  mosquitto = meson.get_compiler('c').find_library('mosquitto', dirs: ldirs, required: false)
  if mosquitto.found()
    mwp_v_args += '--define=MQTT'
    mwp_v_args += '--define=MQTT_MOSQUITTO'
    mwp_v_args += ['--vapidir', vapi_dir, '--pkg', 'libmosquitto']
    mwpdeps +=  mosquitto
    mwpsrcs += files('mwp_mqtt_common.vala')
  endif
endif

spk = false
speak = meson.get_compiler('c').find_library('espeak-ng', dirs: ldirs, required: false).found()
if speak
    xopts += 'USE_ESPEAK_NG'
else
  speak = meson.get_compiler('c').find_library('espeak', dirs: ldirs, required: false).found()
endif

if speak
  mwp_v_args += '--define=USE_ESPEAK'
  spk = true
  xopts += 'USE_ESPEAK'
endif

speak = meson.get_compiler('c').find_library('speechd', dirs: ldirs, required: false).found()
if speak
  mwp_v_args += '--define=USE_SPEECHD'
  xopts += 'USE_SPEECHD'
  spk = true
endif

speak = meson.get_compiler('c').find_library('flite', dirs: ldirs, required: false).found()
if speak
  mwp_v_args += '--define=USE_FLITE'
  xopts += 'USE_FLITE'
  spk = true
endif

if spk
  mwpdeps += dependency('gmodule-2.0')
  foreach x : xopts
    mwp_c_args += '-D'+x
  endforeach
endif

if host_machine.system() == 'windows'
  mwp_v_args += '-X'
  mwp_v_args += '-mwindows'
endif

if paho.found()
  mwp_v_args += ['--pkg', 'paho_wrapper']
endif

common_inc_dir += include_directories('.')

bcd =  dependency('bash-completion', required: false)
if bcd.found()
  if meson.version().version_compare('>=0.51.0')
    bcd_dir = bcd.get_variable(pkgconfig : 'completionsdir')
  else
    bcd_dir = bcd.get_pkgconfig_variable('completionsdir')
  endif
  if not bcd_dir.startswith(get_option('prefix'))
    bcd_dir = join_paths(get_option('prefix'), 'share', 'bash-completion', 'completions')
  endif
  install_data(['mwp_complete.sh'], rename: ['mwp'], install_dir: bcd_dir )
endif

subdir('ui')
subdir('schema')
