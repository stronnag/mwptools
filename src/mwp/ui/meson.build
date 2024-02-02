
install_data (
  ['vcols.css', 'default.layout', 'beep-sound.ogg', 'bleet.ogg',
   'menubar.ui',   'mwpsc.ui',
   'mwp.ui',
   'seeder.ui',
   'fm-dialog.ui',
   'altdialog.ui',
   'bb_dialog.ui',
   'cvt_dialog.ui',
   'delta_dialog.ui',
   'goto_dialog.ui',
   'gps_stats_dialog.ui',
   'map_source_dialog.ui',
   'odoview.ui',
   'otxdialog.ui',
   'pe-dialog.ui',
   'prefs.ui',
   'raw_dialog.ui',
   'shape_dialog.ui',
   'speed_dialog.ui',
   'switch_dialog.ui',
   'wprep_dialog.ui',
   'orange.ogg', 'sat_alert.ogg'],
  install_dir: join_paths(get_option('datadir'), 'mwp')
)

install_subdir('pixmaps', install_dir : join_paths(get_option('datadir'), 'mwp'))
install_data('org.stronnag.mwp.desktop', install_dir : join_paths(get_option('datadir') , 'applications'))
install_data('mwp-mimetypes.xml', install_dir : join_paths(get_option('datadir') , 'mime', 'packages'))
