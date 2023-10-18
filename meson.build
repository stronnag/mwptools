project('mwptools', 'c', 'vala', version : '6.285.743')

# vala / clang16 workaround
if meson.get_compiler('c').get_id() == 'clang'
  add_global_arguments('-Wno-error=incompatible-function-pointer-types', language : 'c')
endif

nogo = get_option('nogo')

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
subdir('src/fc-cli')
subdir('src/qproxy')
subdir('src/samples/')
subdir('docs')

configuration_inc = include_directories('.')

executable('mwp',
	   sources: [mwpsrcs, mwpcommon, mwpvers_h],
	   dependencies: mwpdeps,
	   link_with: libmwpvers,
	   include_directories : [common_inc_dir, configuration_inc],
	   vala_args : [dopts, mwp_v_args],
	   c_args: mwp_c_args,
	   install : true)

executable('cliterm', sources: [clisrcs, clicommon], dependencies: [ clideps ],
  include_directories : common_inc_dir, vala_args : [dopts, cli_v_args], install : true)

executable('gmproxy', sources: proxsrc, dependencies: [ proxdeps ],
	   vala_args : dopts,  install : true)

executable('bproxy', sources: bproxsrc, dependencies: [ proxdeps ],
	   vala_args : dopts, install : true)

executable('fc-get', sources: [fcsrcs, fccommon], dependencies: [ fcdeps ],
  include_directories : common_inc_dir, vala_args : [dopts, fc_v_args], install : true)

executable('ublox-geo',sources: [ ublxgsrcs, ublxguisrc, ublxgcommon]
	   , dependencies: [ ublxgdeps ],
	   include_directories : common_inc_dir,
	   vala_args : [dopts, ublx_v_args],
	   install:false, build_by_default: false )

executable('ublox-cli', sources: [ublxcsrcs, ublxccommon], dependencies: [ ublxcdeps ],
	   include_directories : common_inc_dir, vala_args : [dopts, ublx_v_args],
	   install: false, build_by_default: false )

executable('mwp-area-planner', sources: [apsrcs, apuisrcs, apcommon], dependencies: [ apdeps ],
	   include_directories : common_inc_dir, vala_args : [dopts, ap_v_args],
	   install:true )

executable('flashdl', sources: [fdlsrcs, fccommon], dependencies: [ fdldeps ],
	   include_directories : common_inc_dir, vala_args : [dopts, fdl_v_args],
	   install : false, build_by_default: false )

subdir('src/bbox-replay')

if nogo == false and gook == true and gotrim != ''
  mpe_dir = join_paths(meson.current_source_dir(), 'cmd', 'mwp-plot-elevations')

  r = run_command('meson/find_files.sh', mpe_dir, check: true)
  elev_files = r.stdout().strip().split()
  r = run_command('meson/find_files.sh', join_paths(meson.current_source_dir(), 'pkg','geo'), check: true)
  geo_files = r.stdout().strip().split()

  mpe = custom_target(
    'mwp-plot-elevations',
    output: 'mwp-plot-elevations',
    input: [elev_files, geo_files],
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s', mpe_dir ],
    build_by_default: true,
    install: true,
    install_dir: 'bin')

  fgo_dir = join_paths(meson.current_source_dir(), 'cmd', 'flashgo')
  r = run_command('meson/find_files.sh', fgo_dir, check: true)
  fgo_files = r.stdout().strip().split()

  fgo = custom_target(
    output: 'flashgo',
    input: [fgo_files],
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s',  fgo_dir ],
    build_by_default: true,
    install: true,
    install_dir: 'bin')

  mlr_dir = join_paths(meson.current_source_dir(), 'cmd', 'mwp-log-replay')
  r = run_command('meson/find_files.sh', mlr_dir, check: true)
  mlr_files = r.stdout().strip().split()

  log_replay = custom_target(
    'mwp-log-replay',
    output: 'mwp-log-replay',
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s',  mlr_dir ],
    build_by_default: true,
    input: mlr_files,
    install: true,
    install_dir: 'bin')

  msc_dir = join_paths(meson.current_source_dir(), 'cmd', 'mwp-serial-cap')
  r = run_command('meson/find_files.sh', msc_dir, check: true)
  msc_files = r.stdout().strip().split()

  serial_cap = custom_target(
    'mwp-serial-cap',
    output: 'mwp-serial-cap',
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s',  msc_dir ],
    build_by_default: true,
    input: msc_files,
    install: true,
    install_dir: 'bin')

endif

meson.add_install_script('meson/post_install.sh')
if meson.version().version_compare('> 0.58')
  gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true
  )
else
 meson.add_install_script('meson/legacy_post_install.sh')
endif
