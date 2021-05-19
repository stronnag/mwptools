
mwpcommon = files('btdev.c',
		  'cserial.c',
		  'xmlio.vala',
		  'serial-device.vala',
		  'geocalc.vala',
		  'utils.vala',
		  'mspmsg.vala',
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
		  'mspmsg.vala',
		  'mspcmd.vala',
		  'mwplog.vala',
		  'devman.vala'
		 )

fccommon = files('btdev.c',
	    	  'cserial.c',
		  'serial-device.vala',
		  'mspmsg.vala',
		  'mspcmd.vala',
		  'mwplog.vala',
		  'devman.vala',
		  'mwptermcap.vala'
		 )

ublxgcommon = files('cserial.c',
		    'utils.vala',
		    'geocalc.vala',
		    'mwplog.vala',
		    'devman.vala'
		   )

ublxccommon = files('cserial.c',
		    'mwplog.vala',
		    'devman.vala'
		   )

common_inc_dir = []
common_inc_dir += include_directories('.')
vapi_dir = meson.current_source_dir()

install_data(
  'mwp_icon.svg',
  rename:  'mwp.svg',
  install_dir: get_option('datadir') / 'mwp'
)

install_data('mwp_icon.svg', install_dir: get_option('datadir') / 'mwp')
install_data('mwp_icon.svg', install_dir: get_option('datadir') / 'mwp/pixmaps')
install_data('mwp_icon.svg', install_dir: get_option('datadir') / 'pixmaps')
install_data('mwp_icon.svg', install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps')
