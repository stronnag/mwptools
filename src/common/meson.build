mwpcommon = files('btdev.c',
		  'cserial.c',
		  'mwp_glinfo.c',
		  'xmlio.vala',
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
		 'xmlio.vala',
		 'geocalc.vala',
		 'mspcmd.vala')


common_inc_dir = []
common_inc_dir += include_directories('.')
vapi_dir = meson.current_source_dir()

gatt_c_args = []
gatt_v_args = []
gatt_deps = []

if with_gatt
#  ldirs = ['/usr/lib', '/usr/local/lib']
#  gattlib = meson.get_compiler('c').find_library('gattlib', dirs: ldirs, required: false)
#  if gattlib.found()
    gatt_c_args += '-D HAVE_GATTLIB'
    gatt_deps += gattlib_lib_deps
    gatt_v_args += '--define=GATTLIB'
else
  message('Not checking gattlib')
endif

gatt_deps += dependency('gio-2.0')
gatt_src = files('mwp-gatt-bridge.c')
gatt_v_args += [ '--pkg', 'mwp-gatt-bridge']

install_data('mwp_icon.svg', install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps')
