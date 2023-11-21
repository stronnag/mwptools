project('mwptools', 'c', 'vala', version : '6.325.470', meson_version : '>= 0.60')

# vala / clang16 workaround
if meson.get_compiler('c').get_id() == 'clang'
  add_global_arguments('-Wno-error=incompatible-function-pointer-types', language : 'c')
endif

nogo = get_option('nogo')
with_gatt = get_option('with-gatt')

if build_machine.system() != 'linux'
  with_gatt = false
endif

conf_data = configuration_data()
conf_data.set('version', meson.project_version())
configure_file(
  input : 'src/common/mwp-config.h.in',
  output : 'mwp-config.h',
  configuration : conf_data
)

configuration_inc = []
gattlib_lib_deps=[]
gattpath = get_option('prefix')+'/lib/mwp'

subdir('meson')

if with_gatt
  cmake   = import('cmake')
  opt_var = cmake.subproject_options()
  opt_var.add_cmake_defines({'GATTLIB_PYTHON_INTERFACE': false,
                             'GATTLIB_BUILD_EXAMPLES': false,
                             'CMAKE_INSTALL_LIBDIR': 'lib/mwp',})
  sub_proj = cmake.subproject('gattlib', options: opt_var)
  gattlib_lib_deps = sub_proj.dependency('gattlib')
endif

subdir('src/common')
subdir('src/mwp')
subdir('src/fc-cli')
subdir('src/qproxy')
subdir('src/samples/')
subdir('src/mwp-gatt-bridge')
subdir('docs')

executable('mwp',
	   sources: [mwpsrcs, mwpcommon, gatt_src, mwpvers_h],
	   dependencies: [mwpdeps, gatt_deps],
	   link_with: libmwpvers,
	   include_directories : [common_inc_dir, configuration_inc],
	   vala_args : [dopts, mwp_v_args, gatt_v_args],
	   c_args: [mwp_c_args, gatt_c_args],
	   install : true,
           install_rpath: gattpath
          )

executable('cliterm',
           sources: [clisrcs, clicommon, gatt_src],
           dependencies: [ clideps, gatt_deps ],
           include_directories : common_inc_dir,
           vala_args : [dopts, cli_v_args, gatt_v_args ],
           c_args: gatt_c_args,
           install : true,
           install_rpath: gattpath
          )

executable('bproxy',
           sources: bproxsrc,
           dependencies: [ proxdeps ],
	   vala_args : dopts,
           install : true)

executable('fc-get',
           sources: [fcsrcs, fccommon, gatt_src],
           dependencies: [ fcdeps, gatt_deps ],
           include_directories : common_inc_dir,
           vala_args : [dopts, fc_v_args, gatt_v_args ],
           c_args: gatt_c_args,
           install : true,
           install_rpath: gattpath
          )

executable('ublox-geo',
           sources: [ ublxgsrcs, ublxguisrc, ublxgcommon],
	   dependencies: [ ublxgdeps ],
	   include_directories : common_inc_dir,
	   vala_args : [dopts, ublx_v_args],
	   install:false,
           build_by_default: false)

executable('ublox-cli', sources: [ublxcsrcs, ublxccommon], dependencies: [ ublxcdeps ],
	   include_directories : common_inc_dir, vala_args : [dopts, ublx_v_args],
	   install: false, build_by_default: false )

executable('mwp-area-planner', sources: [apsrcs, apuisrcs, apcommon], dependencies: [ apdeps ],
	   include_directories : common_inc_dir, vala_args : [dopts, ap_v_args],
	   install:true
	   )

executable('flashdl',
           sources: [fdlsrcs, fccommon,  gatt_src],
           dependencies: [ fdldeps, gatt_deps],
	   include_directories : common_inc_dir,
           vala_args : [dopts, fdl_v_args, gatt_v_args ],
           build_by_default: false,
           install : false,
           install_rpath: gattpath+'/lib',
	   install_tag : 'flashdl',
          )

executable('gmproxy',
           sources: proxsrc,
           dependencies: [ proxdeps ],
	   vala_args : dopts,
           build_by_default: false,
           install : false,
           install_tag: 'gmproxy',
	   )

if with_gatt
  executable('mwp-gatt-bridge',
           sources: [gatt_app_src, gatt_src],
           dependencies: [gatt_deps],
           include_directories : common_inc_dir,
           vala_args : [ dopts, gatt_v_args, gatt_app_v_args ],
           c_args: gatt_c_args,
           build_by_default: true,
           install : true,
           install_rpath: gattpath
	   )
endif

subdir('src/bbox-replay')

if nogo == false and gook == true and gotrim != ''
  subdir('pkg/geo')
  subdir('cmd/mwp-plot-elevations')
  mpe = custom_target(
    'mwp-plot-elevations',
    output: 'mwp-plot-elevations',
    input: [mpe_files, geo_files],
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s', mpe_dir ],
    build_by_default: true,
    install: true,
    install_dir: 'bin')

  subdir('cmd/flashgo')
  fgo = custom_target(
    'flashgo',
    output: 'flashgo',
    input: [fgo_files],
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s',  fgo_dir ],
    build_by_default: true,
    install: true,
    install_dir: 'bin')

  subdir('cmd/mwp-log-replay')
  log_replay = custom_target(
    'mwp-log-replay',
    output: 'mwp-log-replay',
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s',  mlr_dir ],
    build_by_default: true,
    input: mlr_files,
    install: true,
    install_dir: 'bin')

  subdir('cmd/mwp-serial-cap')
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
if meson.version().version_compare('>= 0.59')
  gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true
  )
else
 meson.add_install_script('meson/legacy_post_install.sh')
endif
