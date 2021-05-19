
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

ublxguisrc = files('settings.vala',  'mapsources.vala')

apuisrcs = files('settings.vala',  'mapsources.vala', 'mission.vala')

mwpdeps = [deps,
	   dependency('gtk+-3.0'),
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

# for BSD etc.
ldirs = ['/usr/lib', '/usr/local/lib']

paho = meson.get_compiler('c').find_library('paho-mqtt3cs', dirs: ldirs, required: false)

if paho.found()
  dopts += 'MQTT'
  dopts += 'MQTT_PAHO'
  mwpdeps += paho
  mwpsrcs += files('paho_wrapper.c', 'mwp_mqtt_common.vala')
else
  mosquitto = meson.get_compiler('c').find_library('mosquitto', dirs: ldirs, required: false)
  if mosquitto.found()
    dopts += 'MQTT'
    dopts += 'MQTT_MOSQUITTO'
    mwpdeps += mosquitto
    mwpsrcs += files('mwp_mqtt_common.vala')
  endif
endif

spk = false
speak = meson.get_compiler('c').find_library('espeak-ng', dirs: ldirs, required: false).found()
if not speak
  speak = meson.get_compiler('c').find_library('espeak', dirs: ldirs, required: false).found()
endif

if speak
  dopts += 'USE_ESPEAK'
  xopts += 'USE_ESPEAK'
  spk = true
endif

speak = meson.get_compiler('c').find_library('speechd', dirs: ldirs, required: false).found()
if speak
  dopts += 'USE_SPEECHD'
  xopts += 'USE_SPEECHD'
  spk = true
endif

speak = meson.get_compiler('c').find_library('flite', dirs: ldirs, required: false).found()
if speak
  dopts += 'USE_FLITE'
  xopts += 'USE_FLITE'
  spk = true
endif

mwp_c_args=[]

gitvers='local'
r = run_command('git', 'rev-parse','--short','HEAD')
if r.returncode() == 0
  gitvers = r.stdout().strip()
endif
mwp_c_args += '-DMWPGITVERSION=' + gitvers

gitstamp='0000-00-00T00:00:00'
r = run_command('git', 'log','-1','--format=%cI')
if r.returncode() == 0
  gitstamp = r.stdout().strip()
endif
mwp_c_args += '-DMWPGITSTAMP=' + gitstamp

r = run_command('date', '+%FT%T')
if r.returncode() == 0
  bstamp = r.stdout().strip()
else
  bstamp='0000-00-00T00:00:00'
endif
mwp_c_args += '-DMWPSTAMP=' + bstamp

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

mwp_v_args = ['--vapidir', vapi_dir, '--pkg', 'mwpfuncs']

foreach d : dopts
  mwp_v_args += '-D'
  mwp_v_args += d
endforeach
if paho.found()
  mwp_v_args += ['--pkg', 'paho_wrapper']
endif

common_inc_dir += include_directories('.')

install_data (
  'org.mwptools.planner.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0/schemas'
)

install_data (
  ['vcols.css', 'default.layout', 'beep-sound.ogg', 'bleet.ogg',
   'menubar.ui', 'mwp.ui', 'orange.ogg', 'sat_alert.ogg'],
  install_dir: get_option('datadir') / 'mwp'
)

install_subdir('pixmaps', install_dir : get_option('datadir') / 'mwp')
install_data('mwp.desktop', install_dir : get_option('datadir') / 'applications')

bcd =  dependency('bash-completion', required: false)
if bcd.found()
  bcd_dir = bcd.get_variable(pkgconfig : 'completionsdir')
  if bcd_dir.startswith(get_option('prefix'))
    install_data(['mwp_complete.sh', 'blackbox_decode_complete.sh'],
		 rename: ['mwp','blackbox-devcode'],
		 install_dir: bcd_dir )
  endif
endif
