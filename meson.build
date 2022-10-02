project('mwptools', 'c', 'vala', version : '5.275.498')

conf_data = configuration_data()
conf_data.set('version', meson.project_version())
configure_file(
  input : 'src/common/mwp-config.h.in',
  output : 'mwp-config.h',
  configuration : conf_data
)

subdir('meson')
subdir('src/common')
subdir('src/mwp')
subdir('src/mwp-plot-elevations')
subdir('src/fc-cli')
subdir('src/qproxy')
subdir('src/samples/')
subdir('docs')

configuration_inc = include_directories('build')

executable('mwp', mwpsrcs, mwpcommon, dependencies: [ mwpdeps ],
	   include_directories : common_inc_dir, vala_args : [dopts, mwp_v_args],
	   c_args: mwp_c_args,  install : true)

executable('cliterm', clisrcs, clicommon, dependencies: [ clideps ],
  include_directories : common_inc_dir, vala_args : [dopts, cli_v_args], install : true)

executable('gmproxy', proxsrc, dependencies: [ proxdeps ], install : true)
executable('bproxy', bproxsrc, dependencies: [ proxdeps ], install : false, build_by_default: false)

executable('fc-get', fcsrcs, fccommon, dependencies: [ fcdeps ],
  include_directories : common_inc_dir, vala_args : [dopts, fc_v_args], install : true)

executable('ublox-geo', ublxgsrcs, ublxguisrc, ublxgcommon, dependencies: [ ublxgdeps ],
  include_directories : common_inc_dir, vala_args : [dopts, ublx_v_args], install:false, build_by_default: false )
executable('ublox-cli', ublxcsrcs, ublxccommon, dependencies: [ ublxcdeps ],
  include_directories : common_inc_dir, vala_args : [dopts, ublx_v_args], install: false, build_by_default: false )

executable('mwp-area-planner', apsrcs, apuisrcs, apcommon, dependencies: [ apdeps ],
  include_directories : common_inc_dir, vala_args : [dopts, ap_v_args], install:true )

executable('flashdl', fdlsrcs, fccommon, dependencies: [ fdldeps ],
  include_directories : common_inc_dir, vala_args : [dopts, fdl_v_args], install : false, build_by_default: false )

subdir('src/bbox-replay')

if gobuild != ''
   if gotrim != ''
     mpe = custom_target('mwp-plot-elevations', output: 'mwp-plot-elevations', command : [gobuild, '@OUTPUT@', mpe_dir, gotrim], build_by_default: true, input: mpe_deps)

     fgo = custom_target('flashgo', output: 'flashgo', command : [gobuild, '@OUTPUT@', fgo_dir, gotrim], build_by_default: true, input: fgo_deps)

   endif
endif

if meson.version().version_compare('> 0.58')
  meson.add_install_script('meson/trivial_post_install.sh')
  gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true
  )
else
 meson.add_install_script('meson/post_install.sh')
endif
