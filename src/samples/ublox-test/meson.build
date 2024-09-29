
ublxcsrcs = files('ublox-cli.vala', 'ublox-io.vala')
ublxcdeps =  [deps,
	      dependency('gio-2.0'),
	      meson.get_compiler('vala').find_library('posix')
	     ]

ublx_v_args = ['--vapidir', meson.current_source_dir(), '--pkg', 'ublox']
common_inc_dir += include_directories('.')
