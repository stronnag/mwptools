mwpcommon = files('xmlio.vala',
                  'autoland.vala',
		  'cliterm.vala',
		  'json_io.vala',
                  'txtio.vala',
                 )
#mwpcommon = files()

vcommon = files( 'serial-device.vala',
		'mwp_uriparser.vala',
		'geocalc.vala',
		'utils.vala',
		'mspmsg.vala',
		'sede.vala',
		'mspcmd.vala',
		'mwc.vala',
		'mwplog.vala',
		'mavcmd.vala',
		'mlock.vala',
		'devman.vala',
                'track_data.vala',
               )

clicommon = ''

fccommon = files( 'mwptermcap.vala')

ublxgcommon = ''

ublxccommon = ''

apcommon = files('xmlio.vala',
                 'autoland.vala'
                )

common_inc_dir += include_directories('.')


dev_args = []
cli_args = []

rpath =  '$ORIGIN/../lib'

if meson.get_compiler('c').get_id() == 'clang'
  cli_args += ['-D_DEFAULT_SOURCE=1']
endif

if host_machine.system() == 'linux'
  vcommon += files('usbmgr.vala', 'bluez.vala', 'bluetooth.vala', 'ble-helper.vala', 'btdevice.vala', 'ble_uuids.vala' )
endif

dopts += ['--vapidir', meson.current_source_dir() ]

libargs = {
  'sources': vcommon,
  'include_directories':  common_inc_dir,
  'dependencies': [ deps, dependency('gio-2.0'),
                    meson.get_compiler('vala').find_library('posix'),
                    meson.get_compiler('vala').find_library('linux'),
                  ],
  'vala_args': dopts,
  'c_args': [dev_args, vcargs],
  'link_with': mwpclib,
  'install': true,
}

libargs += { 'install_dir': [ get_option('prefix') / 'lib', true, true] }

if dynalib
  libargs += {  'version': '2.0.0', 'soversion': '2', }
  libargs += { 'install_rpath': '$ORIGIN/../lib', }
  mwpvlib = both_libraries('mwpvlib', kwargs: libargs)
else
  mwpvlib = static_library('mwpvlib', kwargs: libargs)
endif

install_data('mwp_icon.svg', install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps')
