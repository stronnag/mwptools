
apresources = gnome.compile_resources(
    'ap-resources',
    'survey.gresources.xml',
    source_dir: '.',
    c_name: 'ap'
)

apsrcs = files('survey.vala', 'genpat.vala')

apsrcs += apresources

apdeps =  [deps,
	      dependency('gio-2.0'),
	      dependency('gtk+-3.0'),
	      dependency('atk'),
	      dependency('clutter-1.0'),
	      dependency('champlain-gtk-0.12'),
	      dependency('champlain-0.12'),
	      dependency('clutter-gtk-1.0'),
              soupdep,
	      dependency('libxml-2.0'),
	      meson.get_compiler('vala').find_library('posix'),
	  ]


if host_machine.system() == 'windows'
  ap_v_args += '-X'
  ap_v_args += '-mwindows'
endif

ap_v_args = []

install_data(
  'mwp_area_icon.svg', install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps'
)
install_data('mwp-area-planner.desktop', install_dir : get_option('datadir') / 'applications')
