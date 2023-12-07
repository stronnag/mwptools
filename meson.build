project('mwptools', 'c', 'vala', version : '6.341.482', meson_version : '>= 0.60')

# vala / clang16 workaround
if meson.get_compiler('c').get_id() == 'clang'
  add_global_arguments('-Wno-error=incompatible-function-pointer-types', language : 'c')
endif

nogo = get_option('nogo')

with_gatt = true
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
common_inc_dir = []

subdir('meson')

subdir('src/common')
subdir('src/mwp')
subdir('src/fc-cli')
subdir('src/qproxy')
subdir('src/samples/')
subdir('src/mwp-ble-bridge')
subdir('docs')

executable('mwp',
	   sources: [mwpsrcs, mwpcommon, dev_src, mwpvers_h],
	   dependencies: [mwpdeps ],
	   link_with: libmwpvers,
	   include_directories : [common_inc_dir, configuration_inc],
	   vala_args : [dopts, mwp_v_args ],
	   c_args: [mwp_c_args, dev_args ],
	   install : true,
          )

executable('cliterm',
           sources: [clisrcs, clicommon, dev_src ],
           dependencies: [ clideps ],
           include_directories : common_inc_dir,
           vala_args : [dopts, cli_v_args ],
           c_args: [dev_args],
           install : true,
          )

executable('bproxy',
           sources: bproxsrc,
           dependencies: [ proxdeps ],
	   vala_args : dopts,
           install : true)

executable('fc-get',
           sources: [fcsrcs, fccommon, dev_src],
           dependencies: [ fcdeps ],
           include_directories : common_inc_dir,
           vala_args : [dopts, fc_v_args ],
           c_args: [dev_args],
           install : true,
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
           sources: [fdlsrcs, fccommon,  dev_src],
           dependencies: [ fdldeps ],
	   include_directories : common_inc_dir,
           vala_args : [dopts, fdl_v_args ],
           c_args: [dev_args],
           build_by_default: false,
           install : false,
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
  executable('mwp-ble-bridge',
           sources: [gatt_app_src, bt_src],
           dependencies: [gatt_deps],
           vala_args : [ dopts ],
           c_args: [dev_args],
           build_by_default: true,
           install : true,
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
