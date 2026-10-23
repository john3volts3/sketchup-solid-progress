require 'sketchup.rb'
require 'extensions.rb'

module SolidProcedural
  PLUGIN_DIR = File.dirname(__FILE__)
  PLUGIN_NAME = 'Solid Procedural'.freeze

  ext = SketchupExtension.new(PLUGIN_NAME, File.join('solid_procedural', 'main'))
  ext.description = 'Non-destructive procedural solids using native SketchUp Pro boolean tools'
  ext.version = '1.0.0'
  ext.creator = 'DRO'
  ext.copyright = '2026'

  Sketchup.register_extension(ext, true)
end
