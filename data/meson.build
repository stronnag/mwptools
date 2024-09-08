blpfiles = files(
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
)

blueprints = custom_target('blueprints',
  input: blpfiles,
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)

mresources = gnome.compile_resources(
  'm-resources',
  'mwp.gresource.xml',
  source_dir: 'data',
  c_name: 'm',
  dependencies: [blueprints, blpfiles]
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
