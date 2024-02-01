project(
  'notedown',
  'vala',
  version: '0.48.7',
  license: 'LGPL2.1+',
)

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
    )
  ],
  c_args: [],
  install: true
)