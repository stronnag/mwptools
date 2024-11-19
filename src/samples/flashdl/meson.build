fdlsrcs = files('flashdl.vala')
fdldeps = [deps,
	   dependency('gio-2.0'),
           meson.get_compiler('vala').find_library('posix'),
           meson.get_compiler('vala').find_library('linux'),
	  ]

fdl_v_args = []
if termcap.found()
  fdldeps += dependency('ncurses')
  fdl_v_args += ['-D', 'USE_TERMCAP']
endif
