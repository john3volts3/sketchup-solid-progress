require 'sketchup.rb'
require 'extensions.rb'

module SolidProcedural
  PLUGIN_DIR = File.dirname(__FILE__)
  PLUGIN_NAME = 'Solid Progress'.freeze

  ext = SketchupExtension.new(PLUGIN_NAME, File.join('solid_progress', 'main'))
  ext.description = 'Non-destructive boolean solids, editable until you finalize them: native booleans with SketchUp Pro, ' \
                    'built-in engine with SketchUp Make'
  ext.version = '2.0.5'
  ext.creator = 'DRO'
  ext.copyright = '2026'

  Sketchup.register_extension(ext, true)
end
