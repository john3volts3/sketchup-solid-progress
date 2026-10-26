# encoding: UTF-8
#-------------------------------------------------------------------------------
#
#  Solid Progress - demo model (development tool, not shipped in the .rbz).
#
#  1. In SketchUp: File > New, then in the Ruby console:
#       load "<project folder>/tools/demo/build_demo.rb"
#     The demo is built in that new model (a saved model is never changed;
#     an untitled model with changes, after a confirmation): two scenes,
#     sizes in meters (a part
#     modeled in meters, exported in millimeters for 3D printing, keeps its
#     small faces and stays well framed).
#  2. Look at it, then, in SketchUp 2021 or later:
#       SolidProcedural::Demo.save
#     It writes tools/tests/results/demo.skp (SketchUp 2021 format) and
#     demo-2017.skp (SketchUp 2017 format) as copies of the model, itself
#     saved in the public Documents folder of Windows (a SketchUp file keeps
#     the path of its last save: that one names no user). The published demo
#     model, docs/demo.skp, is made by hand: never written here.
#     (tools/tests/run_tests.ps1 -Demo does steps 1 and 2 by itself.)
#
#  The holes take the subtract color of Solid Progress: the files are saved
#  only with the default red. SketchUp Make 2017 builds the demo with its
#  built-in engine, but cannot write the 2021 format.
#
#  The scenes keep the camera only: a scene that kept the hidden objects
#  would show again the sources or the Result of a former edit.
#
#  Checked by tools/tests/run_tests.rb: T17 builds it.
#
#-------------------------------------------------------------------------------

module SolidProcedural
  module Demo
    path = File.expand_path(__FILE__)
    path.force_encoding('UTF-8') if path.respond_to?(:force_encoding)
    DEMO_DIR = File.dirname(path)
    OUT_DIR = File.join(File.expand_path('..', DEMO_DIR), 'tests', 'results')
    LOG = '[Solid Progress demo]'.freeze

    # A step of the demo failed: the message tells which one.
    class DemoError < StandardError; end

    # Scene name and the part it shows.
    SCENES = [['1 Create', :raw], ['2 Edit', :plate]].freeze
    FILES = [['demo.skp', :VERSION_2021], ['demo-2017.skp', :VERSION_2017]].freeze
    VIEW_DIRECTION = Geom::Vector3d.new(-1.0, -1.4, 1.0)
    # Camera moved back after the zoom: a margin around the part.
    VIEW_MARGIN = 1.3

    METER = defined?(Length::Meter) ? Length::Meter : 4
    DECIMAL = defined?(Length::Decimal) ? Length::Decimal : 0

    # Plate with pin, in m, plate corner at x = RAW_X (scene 1, volumes not
    # grouped yet) and x = PLATE_X (scene 2, Solid Progress group). The hole
    # goes through the plate and the pin (a tube); with the pin after the
    # hole, the pin is full again. The hole sticks out of the pin: seen in
    # scene 1. The volumes overlap instead of touching (no coplanar faces),
    # and the parts are far apart (a scene shows one part).
    RAW_X = 0
    PLATE_X = 160
    PLATE = { w: 60, d: 40, h: 8 }.freeze
    PIN = { r: 8, z: 6, h: 22, segments: 32 }.freeze
    HOLE = { r: 5, z: -2, h: 36, segments: 32 }.freeze
    PLATE_ORDER = %w[Plate Pin Hole].freeze
    GROUP_NAME = 'Plate with pin'.freeze

    COLORS = {
      'Demo Plate' => [205, 190, 150],
      'Demo Pin' => [90, 140, 200]
    }.freeze

    # -------------------------------------------------------------------
    # Console entries
    # -------------------------------------------------------------------

    # Builds the demo in the active model, if it is new and unchanged.
    def self.start
      model = Sketchup.active_model
      unless defined?(SolidProcedural::Procedural)
        return tell('Solid Progress is not loaded in this SketchUp.', true)
      end
      unless model.path.to_s.empty?
        return tell('Open a new, empty model first (File > New), then load this file again: ' \
                    'the demo never changes a saved model.', true)
      end
      # Another extension may change a new model: ask before replacing.
      if model.modified? &&
         UI.messagebox("This untitled model has changes (another extension may change a new model).\n" \
                       'Build the demo in it? Its content will be replaced.', MB_YESNO) != IDYES
        return tell('nothing was built.')
      end
      started = Time.now
      model.start_operation('Solid Progress Demo — clear the template', true)
      model.entities.erase_entities(model.entities.to_a) unless model.entities.length.zero?
      model.pages.to_a.each { |p| model.pages.erase(p) } if model.pages.respond_to?(:erase)
      model.commit_operation
      parts = build(model)
      setup(model, parts)
      next_step = if Sketchup.version.to_i >= 21
                    'look at it, then type SolidProcedural::Demo.save to write it in tools/tests/results'
                  else
                    'this SketchUp does not save it (the files are written by SketchUp 2021)'
                  end
      tell(format('built in %.1f s: %s.', Time.now - started, next_step))
    rescue DemoError => e
      tell("stopped: #{e.message} Nothing was saved.", true)
    end

    # Writes the two demo files in tools/tests/results as copies. Returns
    # true when both are written.
    def self.save
      model = Sketchup.active_model
      problem = save_problem(model)
      if problem
        tell("not saved: #{problem}", true)
        return false
      end
      model.selection.clear
      # save_copy needs a model saved once: saved first elsewhere, so that a
      # later Ctrl+S never overwrites the copies. Every file keeps the path
      # of that save: the public folder of Windows, which names no user.
      require 'tmpdir'
      folder = ENV['PUBLIC'] ? File.join(ENV['PUBLIC'], 'Documents') : Dir.tmpdir
      path = File.join(folder, 'solid_progress_demo.skp')
      user = ENV['USERNAME'] || ENV['USER']
      if user && path.downcase.include?(user.downcase)
        tell("not saved: the files would keep the path #{path}, which names the user.", true)
        return false
      end
      unless model.save(path)
        tell("the model could not be saved in #{folder}.", true)
        return false
      end
      FILES.each do |name, version|
        Dir.mkdir(OUT_DIR) unless File.directory?(OUT_DIR)
        path = File.join(OUT_DIR, name)
        unless model.save_copy(path, Sketchup::Model.const_get(version))
          tell("#{name} could not be written.", true)
          return false
        end
        tell("#{name} written (#{(File.size(path) / 1024.0).round} KB)")
      end
      true
    end

    def self.save_problem(model)
      return 'saving needs SketchUp 2021 or later (it writes the 2021 and 2017 formats).' if Sketchup.version.to_i < 21
      unless model.pages.map(&:name) == SCENES.map(&:first)
        return 'this model is not the demo: build it first (see tools/demo/build_demo.rb).'
      end
      return 'close the open group first.' unless (model.active_path || []).empty?
      stale = Procedural.all_groups(model).select { |g| Procedural.stale?(g) }
      return "rebuild first: #{stale.map(&:name).join(', ')}." unless stale.empty?
      hole = model.entities.grep(Sketchup::Group).find { |g| g.name == 'Hole' }
      red = Sketchup::Color.new(*SolidProcedural::DEFAULT_SUBTRACT_COLOR)
      unless hole && hole.material && SolidProcedural.color_match?(hole.material.color, red)
        return 'the holes do not have the default red subtract color: run Set Subtract Color ' \
               'on an object painted RGB(255, 0, 0), then build the demo again in a new model.'
      end
      nil
    end

    def self.tell(message, box = false)
      puts "#{LOG} #{message}"
      Sketchup.status_text = "#{LOG} #{message}"
      UI.messagebox(message, MB_OK) if box
      nil
    end

    # -------------------------------------------------------------------
    # Build
    # -------------------------------------------------------------------

    # Builds the two parts of the demo in +model+ from +origin+, with the
    # commands of the plugin. Returns { raw: [volumes], plate: group }.
    # Raises DemoError.
    def self.build(model, origin = ORIGIN)
      model.start_operation('Solid Progress Demo — volumes', true)
      raw = plate_volumes(model, at(origin, RAW_X, 0, 0))
      plate = plate_volumes(model, at(origin, PLATE_X, 0, 0))
      model.commit_operation
      parts = { raw: raw, plate: create(model, plate, GROUP_NAME, PLATE_ORDER) }
      model.selection.clear
      parts
    end

    def self.plate_volumes(model, o)
      ents = model.active_entities
      w = PLATE[:w]
      d = PLATE[:d]
      plate = volume(ents, 'Plate', material(model, 'Demo Plate')) do |e|
        prism(e, [at(o, 0, 0, 0), at(o, w, 0, 0), at(o, w, d, 0), at(o, 0, d, 0)], PLATE[:h])
      end
      pin = volume(ents, 'Pin', material(model, 'Demo Pin')) do |e|
        cylinder(e, at(o, w / 2.0, d / 2.0, PIN[:z]), PIN)
      end
      hole = volume(ents, 'Hole', Procedural.subtract_material(model)) do |e|
        cylinder(e, at(o, w / 2.0, d / 2.0, HOLE[:z]), HOLE)
      end
      [plate, pin, hole]
    end

    # Create Solid Progress on +volumes+, then the name and the order of
    # the rows, with the Progress Table. Returns the Solid Progress group.
    def self.create(model, volumes, name, order)
      model.selection.clear
      model.selection.add(volumes)
      Procedural.do_create
      group = model.selection.find { |e| Procedural.procedural?(e) }
      raise DemoError, "Create Solid Progress failed for '#{name}' (see the message)." unless group
      model.start_operation('Solid Progress Demo — name', true)
      group.name = name
      model.commit_operation
      if Procedural.sources_of(group).first.name != order.first
        Procedural.table_set_base(model, group, key_of(group, order.first))
      end
      if Procedural.sources_of(group).map(&:name) != order
        Procedural.table_order(model, group, order.map { |n| key_of(group, n) })
      end
      unless Procedural.sources_of(group).map(&:name) == order
        raise DemoError, "The rows of '#{name}' could not be put in order (see the message)."
      end
      group
    end

    # Key of the row of the volume named +name+ in the Progress Table.
    def self.key_of(group, name)
      pair = Procedural.row_lookup(group).find { |_key, source| source.name == name }
      raise DemoError, "No volume '#{name}' in '#{group.name}'." unless pair
      pair[0]
    end

    # -------------------------------------------------------------------
    # Scenes, units
    # -------------------------------------------------------------------

    # Meters, unused template content purged, one scene per part (camera
    # only).
    def self.setup(model, parts)
      model.start_operation('Solid Progress Demo — scenes', true)
      units = model.options['UnitsOptions']
      units['LengthFormat'] = DECIMAL
      units['LengthUnit'] = METER
      units['LengthPrecision'] = 1
      [model.definitions, model.materials, model.layers, model.styles].each do |list|
        list.purge_unused if list.respond_to?(:purge_unused)
      end
      SCENES.each do |name, part|
        frame(model.active_view, [parts[part]].flatten)
        model.pages.add(name, PAGE_USE_CAMERA)
      end
      model.pages.selected_page = model.pages[SCENES.first[0]]
      model.commit_operation
    end

    # Camera of a scene: view from the front left on +ents+, with a margin.
    def self.frame(view, ents)
      bounds = Geom::BoundingBox.new
      ents.each { |e| bounds.add(e.bounds) }
      target = bounds.center
      view.camera = Sketchup::Camera.new(target.offset(VIEW_DIRECTION, bounds.diagonal * 2), target, Z_AXIS)
      view.zoom(ents)
      cam = view.camera
      eye = cam.target.offset(cam.target.vector_to(cam.eye), cam.eye.distance(cam.target) * VIEW_MARGIN)
      view.camera = Sketchup::Camera.new(eye, cam.target, cam.up)
    end

    # -------------------------------------------------------------------
    # Geometry (m)
    # -------------------------------------------------------------------

    def self.at(origin, x, y, z)
      Geom::Point3d.new(origin.x + x.m, origin.y + y.m, origin.z + z.m)
    end

    def self.material(model, name)
      m = model.materials[name] || model.materials.add(name)
      m.color = Sketchup::Color.new(*COLORS[name])
      m
    end

    # Group named +name+ with +material+, its geometry added by the block.
    def self.volume(entities, name, material)
      g = entities.add_group
      yield g.entities
      g.name = name
      g.material = material
      g
    end

    # Face through +points+ (horizontal), pushed up by +h+.
    def self.prism(entities, points, h)
      f = entities.add_face(points)
      f.reverse! if f.normal.z < 0
      f.pushpull(h.m)
    end

    # Vertical cylinder of +spec+ (r, h, segments) on +center+.
    def self.cylinder(entities, center, spec)
      f = entities.add_face(entities.add_circle(center, Z_AXIS, spec[:r].m, spec[:segments]))
      f.reverse! if f.normal.z < 0
      f.pushpull(spec[:h].m)
    end
  end
end

# Loaded by the tests with $sp_demo_no_autorun: nothing is built then.
SolidProcedural::Demo.start unless $sp_demo_no_autorun
