mwpcommon = files('xmlio.vala',
                  'autoland.vala',
		  'cliterm.vala',
		  'json_io.vala',
                  'txtio.vala',
                 )

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
		'devman.vala',
                'track_data.vala',
               )

if build_machine.system() == 'windows'
  vcommon += files('winspawn.vala', 'winproc.c', 'win_suspend_resume.c')
else
  vcommon += files('posixspawn.vala', 'posix_psmisc.c')
endif

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

deps += dependency('gio-2.0')
if host_machine.system() != 'windows'
  deps += dependency('gio-unix-2.0')
else
  deps += dependency('gio-windows-2.0')
endif

libargs = {
  'sources': vcommon,
  'include_directories':  common_inc_dir,
  'dependencies': [ deps,
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
  libargs += {  'version': '3.0.0', 'soversion': '3', }
  libargs += { 'install_rpath': '$ORIGIN/../lib', }
  mwpvlib = both_libraries('mwpvlib', kwargs: libargs)
else
  mwpvlib = static_library('mwpvlib', kwargs: libargs)
endif
