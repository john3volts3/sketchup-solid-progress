require_relative 'version'
require_relative 'circle_restore'
require_relative 'parametric'
require_relative 'parametric_observer'

module SolidProcedural
  unless @loaded
    submenu = UI.menu('Extensions').add_submenu(PLUGIN_NAME)

    submenu.add_item('Create Parametric Solid') { Parametric.do_create }
    submenu.add_item('Rebuild Parametric Solid') { Parametric.do_rebuild }
    submenu.add_item('Finalize Parametric Solid') { Parametric.do_finalize }
    submenu.add_separator
    submenu.add_item('Set Subtract Color') { self.do_set_subtract_color }
    if Sketchup.version.to_f >= 20.1
      submenu.add_item('Set Repair Options') { self.do_set_repair_options }
    end

    toolbar = UI::Toolbar.new(PLUGIN_NAME)

    icons_dir = File.join(PLUGIN_DIR, 'solid_procedural', 'icons')

    cmd_create = UI::Command.new('Create Parametric Solid') { Parametric.do_create }
    cmd_create.tooltip = 'Create Parametric Solid — group the selected solids, result rebuilt on exit'
    cmd_create.small_icon = File.join(icons_dir, 'create_parametric_16.png')
    cmd_create.large_icon = File.join(icons_dir, 'create_parametric_24.png')
    toolbar.add_item(cmd_create)

    cmd_rebuild = UI::Command.new('Rebuild Parametric Solid') { Parametric.do_rebuild }
    cmd_rebuild.tooltip = 'Rebuild Parametric Solid — force the rebuild of the selected parametric solids'
    cmd_rebuild.small_icon = File.join(icons_dir, 'rebuild_parametric_16.png')
    cmd_rebuild.large_icon = File.join(icons_dir, 'rebuild_parametric_24.png')
    toolbar.add_item(cmd_rebuild)

    cmd_finalize = UI::Command.new('Finalize Parametric Solid') { Parametric.do_finalize }
    cmd_finalize.tooltip = 'Finalize Parametric Solid — replace by a plain solid, without its sources'
    cmd_finalize.small_icon = File.join(icons_dir, 'finalize_parametric_16.png')
    cmd_finalize.large_icon = File.join(icons_dir, 'finalize_parametric_24.png')
    toolbar.add_item(cmd_finalize)

    toolbar.add_separator

    cmd_setcolor = UI::Command.new('Set Subtract Color') { self.do_set_subtract_color }
    cmd_setcolor.tooltip = 'Set Subtract Color — pick color from selection'
    cmd_setcolor.small_icon = File.join(icons_dir, 'setcolor_16.png')
    cmd_setcolor.large_icon = File.join(icons_dir, 'setcolor_24.png')
    toolbar.add_item(cmd_setcolor)

    if Sketchup.version.to_f >= 20.1
      cmd_repairopts = UI::Command.new('Set Repair Options') { self.do_set_repair_options }
      cmd_repairopts.tooltip = 'Set Repair Options — circle restoration threshold'
      cmd_repairopts.small_icon = File.join(icons_dir, 'repair_circles_16.png')
      cmd_repairopts.large_icon = File.join(icons_dir, 'repair_circles_24.png')
      toolbar.add_item(cmd_repairopts)
    end

    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      toolbar.show
    else
      toolbar.show
    end
    @loaded = true
  end

  # -------------------------------------------------------------------
  # Options management (persisted across sessions)
  # -------------------------------------------------------------------
  DEFAULT_SUBTRACT_COLOR = [255, 0, 0].freeze
  DEFAULT_AUTO_REPAIR_LARGE = 'Yes'.freeze
  DEFAULT_LARGE_THRESHOLD = 10000
  DEFAULT_MIN_ARC_SEGMENTS = 6

  REGISTRY_SECTION = 'SolidProcedural'.freeze
  # An option not set yet in Solid Procedural is read from Solid Batch v2,
  # so that its current settings carry over.
  LEGACY_REGISTRY_SECTION = 'SolidBatch'.freeze

  def self.read_option(key, default)
    value = Sketchup.read_default(REGISTRY_SECTION, key)
    value = Sketchup.read_default(LEGACY_REGISTRY_SECTION, key) if value.nil?
    value.nil? ? default : value
  end

  def self.subtract_color
    r = read_option('subtract_color_r', DEFAULT_SUBTRACT_COLOR[0]).to_i
    g = read_option('subtract_color_g', DEFAULT_SUBTRACT_COLOR[1]).to_i
    b = read_option('subtract_color_b', DEFAULT_SUBTRACT_COLOR[2]).to_i
    Sketchup::Color.new(r, g, b)
  end

  def self.save_subtract_color(color)
    Sketchup.write_default(REGISTRY_SECTION, 'subtract_color_r', color.red)
    Sketchup.write_default(REGISTRY_SECTION, 'subtract_color_g', color.green)
    Sketchup.write_default(REGISTRY_SECTION, 'subtract_color_b', color.blue)
  end

  def self.auto_repair_large
    read_option('auto_repair_large', DEFAULT_AUTO_REPAIR_LARGE).to_s
  end

  def self.save_auto_repair_large(value)
    Sketchup.write_default(REGISTRY_SECTION, 'auto_repair_large', value.to_s)
  end

  def self.large_threshold
    read_option('large_threshold', DEFAULT_LARGE_THRESHOLD).to_i
  end

  def self.save_large_threshold(value)
    Sketchup.write_default(REGISTRY_SECTION, 'large_threshold', value.to_i)
  end

  def self.min_arc_segments
    read_option('min_arc_segments', DEFAULT_MIN_ARC_SEGMENTS).to_i
  end

  def self.save_min_arc_segments(value)
    Sketchup.write_default(REGISTRY_SECTION, 'min_arc_segments', value.to_i)
  end

  def self.color_match?(c1, c2)
    c1.red == c2.red && c1.green == c2.green && c1.blue == c2.blue
  end

  def self.is_subtract_solid?(entity)
    return false unless entity.material
    color_match?(entity.material.color, subtract_color)
  end

  # -------------------------------------------------------------------
  # Actions
  # -------------------------------------------------------------------
  def self.do_set_subtract_color
    model = Sketchup.active_model
    sel = model.selection.to_a
    entity = sel.find { |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.material
    }

    unless entity
      UI.messagebox(
        "Select a group or component with a material/color applied.\n" \
        "That color will be used to identify the volumes to subtract in parametric solids.",
        MB_OK
      )
      return
    end

    color = entity.material.color
    save_subtract_color(color)
    UI.messagebox(
      "Subtract color set to RGB(#{color.red}, #{color.green}, #{color.blue}).\n" \
      "Volumes painted with this color will be subtracted in parametric solids.\n" \
      "Existing volumes keep their operation until they are repainted.",
      MB_OK
    )
  end

  def self.do_set_repair_options
    prompts = [
      'Auto-repair circles on large objects',
      'Large object threshold (edges)',
      'Min segments for arc detection',
    ]
    defaults = [
      auto_repair_large,
      large_threshold.to_s,
      min_arc_segments.to_s,
    ]
    list = ['Yes|No', '', '']
    title = "#{PLUGIN_NAME} — Repair Options"

    result = UI.inputbox(prompts, defaults, list, title)
    return unless result

    save_auto_repair_large(result[0])

    threshold_value = result[1].to_i
    threshold_value = DEFAULT_LARGE_THRESHOLD if threshold_value <= 0
    save_large_threshold(threshold_value)

    arc_segments = result[2].to_i
    arc_segments = DEFAULT_MIN_ARC_SEGMENTS if arc_segments < 3
    save_min_arc_segments(arc_segments)

    UI.messagebox(
      "Repair options saved:\n\n" \
      "  Auto-repair circles on large objects: #{result[0]}\n" \
      "  Large object threshold: #{threshold_value} edges\n" \
      "  Min segments for arc detection: #{arc_segments}\n\n" \
      "Lower 'Min segments for arc detection' = catches shorter arcs " \
      "but may produce false positives. Higher = safer.\n\n" \
      "When the result of a parametric solid exceeds the large threshold and " \
      "auto-repair is set to No, restoration is skipped (a message is shown).",
      MB_OK
    )
  end
end
