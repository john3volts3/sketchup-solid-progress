# encoding: UTF-8

module SolidProcedural
  # Highlight — green selection frame for procedural solids.
  #
  # SketchUp 2021 has a single selection color, in the style of the model
  # (rendering option HighlightColor). While the selection holds only
  # procedural solids, it is set to GREEN; otherwise the original color comes
  # back. Changing it adds no undo step and does not mark the model as
  # modified (checked in SketchUp 2021).
  #
  # The green is never saved: the original color is put back before each
  # save, and a model opened with this exact green (left by a crash or an
  # autosave) gets back the original color kept in the registry.
  module Highlight
    GREEN = [0, 170, 0].freeze
    DEFAULT_COLOR = [0, 0, 255].freeze
    OPTION = 'HighlightColor'.freeze
    REGISTRY_KEY = 'highlight_original'.freeze
    LOG = '[Solid Procedural]'.freeze

    # Original selection color [r, g, b] of the models shown in green.
    @original ||= {}

    def self.wanted?(model)
      selection = model.selection
      !selection.empty? && selection.all? { |e| Procedural.procedural?(e) }
    end

    def self.green?(color)
      !color.nil? && [color.red, color.green, color.blue] == GREEN
    end

    # Update once SketchUp is idle; several requests make one update.
    def self.update_later
      return if @pending
      @pending = true
      timer = UI.start_timer(0, false) do
        UI.stop_timer(timer)
        @pending = false
        update(Sketchup.active_model)
      end
    end

    def self.update(model)
      return unless model && model.valid?
      wanted?(model) ? show_green(model) : restore(model)
    rescue => e
      puts "#{LOG} Highlight error: #{e.message}"
    end

    def self.show_green(model)
      options = model.rendering_options
      current = options[OPTION]
      return if green?(current)
      original = [current.red, current.green, current.blue]
      @original[model] = original
      Sketchup.write_default(REGISTRY_SECTION, REGISTRY_KEY, original.join(','))
      options[OPTION] = Sketchup::Color.new(*GREEN)
    end

    def self.restore(model)
      original = @original.delete(model)
      model.rendering_options[OPTION] = Sketchup::Color.new(*original) if original
    end

    # Before a save (called in the observer callback, a deferred change
    # would come too late): the original color is the one saved.
    def self.before_save(model)
      restore(model)
    rescue => e
      puts "#{LOG} Highlight error: #{e.message}"
    end

    # Model opened, or undo / redo: a green the plugin does not manage was
    # saved by mistake and gets the original color back.
    def self.repair(model)
      return if @original.key?(model)
      options = model.rendering_options
      return unless green?(options[OPTION])
      rgb = Sketchup.read_default(REGISTRY_SECTION, REGISTRY_KEY).to_s.split(',').map(&:to_i)
      rgb = DEFAULT_COLOR unless rgb.length == 3
      options[OPTION] = Sketchup::Color.new(*rgb)
      puts "#{LOG} Selection color restored to #{rgb.join(', ')}"
    end
  end
end
