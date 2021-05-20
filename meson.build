project('mwptools', 'c', 'vala', version : '4.138.664')

meson.add_install_script('meson/post_install.sh')
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
subdir('src/otxlog')
subdir('src/qproxy')
subdir('src/fc-cli')
subdir('src/samples/')
subdir('docs')

configuration_inc = include_directories('build')

executable('mwp', mwpsrcs, mwpcommon, dependencies: [ mwpdeps ],
	   include_directories : common_inc_dir, vala_args : [dopts, mwp_v_args],
	   c_args: mwp_c_args,  install : true)

executable('cliterm', clisrcs, clicommon, dependencies: [ clideps ],
  include_directories : common_inc_dir, vala_args : [dopts, cli_v_args], install : true)

executable('qproxy', proxsrc, dependencies: [ proxdeps ], install : true)
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

golang = find_program('go')
if golang.found()
  broot = meson.current_source_dir() / 'build'
  mpe = custom_target('mwp-plot-elevations', output: 'mwp-plot-elevations',
		      command : [mpe_build, broot /  '@OUTPUT@'], build_by_default: true)
  otx = custom_target('otxlog', output: 'otxlog', command : [otx_build, broot / '@OUTPUT@'],
		      build_by_default: true)
  bbs = custom_target('bbsummary', output: 'bbsummary',
		      command : [bbs_build, broot / '@OUTPUT@'], build_by_default: true)
endif
