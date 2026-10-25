require 'sketchup.rb'
require 'extensions.rb'

module SolidProcedural
  PLUGIN_DIR = File.dirname(__FILE__)
  PLUGIN_NAME = 'Solid Procedural'.freeze

  ext = SketchupExtension.new(PLUGIN_NAME, File.join('solid_procedural', 'main'))
  ext.description = 'Non-destructive procedural solids: native booleans with SketchUp Pro, ' \
                    'built-in engine with SketchUp Make'
  ext.version = '1.1.0'
  ext.creator = 'DRO'
  ext.copyright = '2026'

  Sketchup.register_extension(ext, true)
end
