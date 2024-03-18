mwpcommon = files('xmlio.vala',
                  'autoland.vala',
		  'cliterm.vala',
		  'json_io.vala'
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
		'mlock.vala',
		'devman.vala')

clicommon = ''

fccommon = files( 'mwptermcap.vala')

ublxgcommon = ''

ublxccommon = ''

apcommon = files('xmlio.vala',
                 'autoland.vala'
                )

devman = files('devman.vala')

common_inc_dir += include_directories('.')
vapi_dir = meson.current_source_dir()

dev_src = []
dev_args = []
cli_args = []

if meson.get_compiler('c').get_id() == 'clang'
  cli_args += ['-D_DEFAULT_SOURCE=1']
endif

if host_machine.system() == 'linux'
  usb_src = files('usbmgr.vala')
  bt_src = files('bluez.vala', 'bluetooth.vala', 'ble-helper.vala', 'btdevice.vala', 'ble_uuids.vala' )
  dev_src = [usb_src, bt_src]
endif

mwpv_args = ['--vapidir', vapi_dir, '--pkg', 'mwpfuncs']

mwpvlib = both_libraries('mwpvlib',
                         sources: [vcommon, dev_src],
                         include_directories :  common_inc_dir,
                         dependencies : [ deps, dependency('gio-2.0'),
                                          meson.get_compiler('vala').find_library('posix'),
                                          meson.get_compiler('vala').find_library('linux'),
                                           ],
                         vala_args : [dopts, mwpv_args],
                         c_args: [dev_args, vcargs],
                         install: true,
                         install_dir: [true, true, true],
                         install_rpath: get_option('prefix') + '/lib',
                         link_with: mwpclib,
                        )

install_data('mwp_icon.svg', install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps')
