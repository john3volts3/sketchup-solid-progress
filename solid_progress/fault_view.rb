# encoding: UTF-8

module SolidProcedural
  # FaultView — where a result is not a solid.
  #
  # After a rebuild refused because a result is not a solid, its edges at
  # fault are drawn in magenta, thick and in front of the faces, until
  # Escape or another tool. The model is not changed: nothing to undo,
  # nothing saved. Magenta, not red: red is the subtract color.
  class FaultView
    COLOR = 'magenta'.freeze
    WIDTH = 4

    # Shows +edges+ ([start, end, face count] in model coordinates).
    def self.show(model, edges)
      return if edges.nil? || edges.empty?
      model.select_tool(new(edges))
    end

    def initialize(edges)
      @edges = edges
    end

    def activate
      Sketchup.status_text = "Solid Progress — #{@edges.length} edge(s) where the result is not a solid, " \
                             'in magenta: Escape to hide them.'
      Sketchup.active_model.active_view.invalidate
    end

    # After a view tool (Orbit, Pan…): the status text again.
    def resume(_view)
      activate
    end

    def deactivate(view)
      view.invalidate
    end

    def onCancel(_reason, _view)
      Sketchup.active_model.select_tool(nil)
    end

    def getExtents
      box = Geom::BoundingBox.new
      @edges.each { |a, b, _faces| box.add(a, b) }
      box
    end

    # In screen coordinates: in front of the faces, seen even inside a
    # volume.
    def draw(view)
      points = @edges.flat_map { |a, b, _faces| [view.screen_coords(a), view.screen_coords(b)] }
      view.line_width = WIDTH
      view.drawing_color = COLOR
      view.draw2d(GL_LINES, points)
    end
  end
end
