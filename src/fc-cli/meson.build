fcsrcs = files('fc-get.vala')
fcdeps = [deps,
	   dependency('gio-2.0'),
           meson.get_compiler('vala').find_library('posix'),
           meson.get_compiler('vala').find_library('linux'),
	  ]

fc_v_args = []

if termcap.found()
  fcdeps += meson.get_compiler('c').find_library('ncurses')
  fc_v_args += ['-D', 'USE_TERMCAP']
endif
