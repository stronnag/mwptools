mwpcommon = files('btdev.c',
		  'cserial.c',
		  'mwp_glinfo.c',
		  'xmlio.vala', 'autoland.vala',
		  'serial-device.vala',
		  'mwp_uriparser.vala',
		  'geocalc.vala',
		  'utils.vala',
		  'mspmsg.vala',
		  'sede.vala',
		  'mspcmd.vala',
		  'mwc.vala',
		  'mwplog.vala',
		  'mavcmd.vala',
		  'cliterm.vala',
		  'mlock.vala',
		  'json_io.vala',
		  'devman.vala')

clicommon = files('btdev.c',
	    	  'cserial.c',
		  'serial-device.vala',
		  'mwp_uriparser.vala',
		  'mspmsg.vala',
		  'sede.vala',
		  'mspcmd.vala',
		  'mwplog.vala',
		  'utils.vala',
		  'devman.vala')

fccommon = files('btdev.c',
	    	  'cserial.c',
		  'serial-device.vala',
		  'mwp_uriparser.vala',
		  'mspmsg.vala',
		  'sede.vala',
		  'mspcmd.vala',
		  'mwplog.vala',
		  'devman.vala',
		  'mwptermcap.vala')

ublxgcommon = files('cserial.c',
		    'utils.vala',
		    'geocalc.vala',
		    'mwplog.vala',
		    'devman.vala')

ublxccommon = files('cserial.c',
		    'mwplog.vala',
		    'devman.vala')

apcommon = files('utils.vala',
		 'mwplog.vala',
		 'xmlio.vala', 'autoland.vala',
		 'geocalc.vala',
		 'mspcmd.vala')

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
  dev_args += '-D_XOPEN_SOURCE=701'
endif

install_data('mwp_icon.svg', install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps')
