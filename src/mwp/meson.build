
mwpsrcs = files('mwp.vala', 'liststore.vala', 'mwp_markers.vala',
              'mwp_craft.vala', 'settings.vala', 'dialogs.vala', 'mapsources.vala',
              'local_geo.vala', 'logger.vala', 'speech_wrapper.c', 'mwp-replay.vala',
              'map_seeder.vala', 'mwp-layout.vala', 'iparser.vala', 'mwp_bbox.vala',
              'ah_widget.vala', '_mwpvers.c', 'get_places.vala', 'mission.vala',
              'mwp_dbus.vala', 'name_type_map.vala', 'mwp_pe_support.vala',
              'kmlovly.vala', 'mwp_upower.vala', 'replicate_wp.vala',
              'mwp-mission-preview.vala', 'mwp-radar_list.vala',
              'dbus-mwp-client.vala', 'mwp_safehomes.vala', 'mwp_otx.vala',
              'mwp_xdg_notify.vala', 'mwp_elevations.vala')

deps += [dependency('gtk+-3.0'),
         dependency('atk'),
         dependency('clutter-1.0'),
         dependency('champlain-gtk-0.12'),
         dependency('champlain-0.12'),
         dependency('libxml-2.0'),
         dependency('gio-2.0'),
         dependency('clutter-gtk-1.0'),
         dependency('gdl-3.0'),
         dependency('pango'),
         dependency('cairo'),
         dependency('libsoup-2.4'),
         dependency('gstreamer-1.0'),
         dependency('vte-2.91'),
         meson.get_compiler('vala').find_library('posix'),
         meson.get_compiler('vala').find_library('linux'),
        ]

if host_machine.system() == 'windows'
  opts += '-mwindows'
endif

paho = meson.get_compiler('c').find_library('paho-mqtt3cs')

if paho.found()
  dopts += 'MQTT'
  dopts += 'MQTT_PAHO'
  deps += paho
  mwpsrcs += files('paho_wrapper.c', 'mwp_mqtt_common.vala')

else
  mosquitto = meson.get_compiler('c').find_library('mosquitto')
  if mosquitto.found()
    dopts += 'MQTT'
    dopts += 'MQTT_MOSQUITTO'
    deps += mosquitto
    mwpsrcs += files('mwp_mqtt_common.vala')
  endif
endif

spk = false
speak = meson.get_compiler('c').find_library('espeak-ng').found()
if not speak
  speak = meson.get_compiler('c').find_library('espeak').found()
endif

if speak
  dopts += 'USE_ESPEAK'
  xopts += 'USE_ESPEAK'
  spk = true
endif

speak = meson.get_compiler('c').find_library('speechd').found()
if speak
  dopts += 'USE_SPEECHD'
  xopts += 'USE_SPEECHD'
  spk = true
endif

speak = meson.get_compiler('c').find_library('flite').found()
if speak
  dopts += 'USE_FLITE'
  xopts += 'USE_FLITE'
  spk = true
endif

mwp_c_args=[]
if spk
  deps += dependency('gmodule-2.0')
  foreach x : xopts
    mwp_c_args += '-D'+x
  endforeach
endif

mwp_v_args = []
foreach d : dopts
  mwp_v_args += '-D'
  mwp_v_args += d
endforeach
mwp_v_args += ['--vapidir', vapi_dir]
mwp_v_args += ['--pkg', 'mwpfuncs']
if paho.found()
  mwp_v_args += ['--pkg', 'paho_wrapper']
endif

common_inc_dir += include_directories('.')
