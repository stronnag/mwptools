blpfiles = [
  'mwpmain.blp',
  'mwpmenu.blp',
  'mwpsc.blp',
  'goto_dialog.blp',
  'kmlremover.blp',
  'wppop.blp',
  'tadialog.blp',
  'safehmenu.blp',
  'totemenu.blp',
  'shapedialog.blp',
  'deltadialog.blp',
  'altdialog.blp',
  'speeddialog.blp',
  'seeder.blp',
  'bb_dialog.blp',
  'fb.blp',
  'rssi.blp',
  'dirn.blp',
  'etx_dialog.blp',
  'raw_dialog.blp',
  'odoview.blp',
  'voltage.blp',
  'mwpjs.blp',
  'gzmenu.blp',
  'fm-dialog.blp',
  'prefs.blp',
  'newpos.blp',
  'shedit.blp',
  'survey.blp',
  'surveymenu.blp',
  'gps_stats_dialog.blp',
  'vas.blp',
]

blueprints_ui = []
blueprints_vala = []
foreach b : blpfiles
  blueprints_ui += b.replace('.blp', '.ui')
  blueprints_vala += b + '.vala'
endforeach

blueprints = custom_target('blueprints',
		           input: blpfiles,
		           output: blueprints_ui,
		           command: [find_program('blueprint-compiler'),
                                     'batch-compile', '@OUTDIR@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
                          )

blueprints_hack = custom_target('blueprints_hack',
                                input: blueprints,
	                        output: blueprints_vala,
		                command: [find_program('touch'), '@OUTPUT@'],
			       )

mresources = gnome.compile_resources(
  'm-resources',
  'mwp.gresource.xml',
  source_dir: 'data',
  c_name: 'm',
  dependencies: [blueprints, ]
)

install_data (
  ['volts.css', 'beep-sound.ogg', 'bleet.ogg', 'orange.ogg', 'sat_alert.ogg'],
  install_dir: join_paths(get_option('datadir'), 'mwp')
)

install_subdir('pixmaps', install_dir : join_paths(get_option('datadir'), 'mwp'))

install_data (
  'org.stronnag.mwp.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)

install_data('org.stronnag.mwp.desktop', install_dir : join_paths(get_option('datadir') , 'applications'))

bcd =  dependency('bash-completion', required: false)
if bcd.found()
  bcd_dir = bcd.get_variable(pkgconfig : 'completionsdir')
  if not bcd_dir.startswith(get_option('prefix'))
    bcd_dir = join_paths(get_option('prefix'), 'share', 'bash-completion', 'completions')
  endif
  install_data(['mwp-completion.sh'], rename: ['mwp'], install_dir: bcd_dir )
endif
