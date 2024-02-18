project(
  'notedown',
  'vala',
  version: '0.48.7',
  license: 'MIT',
)

notedown_prefix = get_option('prefix')
notedown_datadir = join_paths(notedown_prefix, get_option('datadir'))

subdir('data/icons')
subdir('data/web')

gnome = import('gnome')

executable(
  meson.project_name(),
  dependencies: [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gee-0.8'),
    dependency('gio-2.0'),
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('webkitgtk-6.0')
  ],
  sources: [
    files('./src/main.vala'),
    gnome.compile_resources(
      'ui',
      'data/ui.gresource.xml',
      source_dir: 'data'
    ),
    gnome.compile_resources(
      'web',
      'data/web/dist/web.gresource.xml',
      source_dir: 'data/web/dist/'
    )
  ],
  c_args: [],
  install: true
)

gnome.post_install(
  gtk_update_icon_cache: true
)