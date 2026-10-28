# encoding: UTF-8
#-------------------------------------------------------------------------------
#
#  Solid Procedural - automatic tests (development tool, not shipped in the .rbz).
#
#  Fully automatic, from PowerShell (SketchUp closed):
#    tools/tests/run_tests.ps1            (SketchUp 2021, then Make 2017)
#  It deploys the plugin, starts each SketchUp with -RubyStartup on this file,
#  waits for the report and closes SketchUp.
#
#  By hand, in the Ruby console of SketchUp:
#    load "<project folder>/tools/tests/run_tests.rb"
#
#  The plugin files installed in SketchUp are reloaded first. The tests run
#  in a new model (the current one is never changed); message boxes are
#  recorded instead of shown. Steps are chained with timers, so that the
#  deferred work of the plugin (display, selection color, release) runs
#  between them, as it does for the user.
#
#  Report: Ruby console and results/latest-<SketchUp major version>.txt.
#
#  Make 2017 only, by hand (no API opens a group there):
#    SolidProcedural::Tests.manual_open_test
#  then double-click "SP Test - open me" and exit it (see the status bar).
#
#-------------------------------------------------------------------------------

verbose = $VERBOSE
$VERBOSE = nil

module SolidProcedural
  module Tests
    path = File.expand_path(__FILE__)
    path.force_encoding('UTF-8') if path.respond_to?(:force_encoding)
    TESTS_DIR = File.dirname(path)
    PROJECT_DIR = File.expand_path('../..', TESTS_DIR)
    RESULTS_DIR = File.join(TESTS_DIR, 'results')
    STEP_DELAY = 0.5
    LOG = '[Solid Procedural tests]'.freeze

    # One test: checks, notes and the phases still to run.
    class Case
      attr_reader :name, :checks, :notes, :phases
      attr_accessor :skipped

      def initialize(name)
        @name = name
        @checks = []
        @notes = []
        @phases = []
        @skipped = nil
      end

      # Runs the block after a delay, once the deferred work of the plugin
      # is done.
      def later(&block)
        @phases << block
      end

      def check(ok, label, detail = nil)
        @checks << [ok ? true : false, label, detail]
        ok
      end

      def note(text)
        @notes << text
      end

      def skip(reason)
        @skipped = reason
      end

      def failed?
        @checks.any? { |c| !c[0] }
      end
    end

    # -------------------------------------------------------------------
    # Runner
    # -------------------------------------------------------------------

    def self.run
      @started = Time.now
      @cases = []
      @state = {}
      @messages = []
      @status = []
      @tests = []
      define_tests
      reload_plugin
      hook
      prepare_model(0) { next_test }
    rescue => e
      fatal(e)
    end

    def self.messages
      @messages
    end

    def self.status
      @status
    end

    def self.schedule(&block)
      timer = UI.start_timer(STEP_DELAY, false) do
        UI.stop_timer(timer)
        begin
          block.call
        rescue => e
          fatal(e)
        end
      end
    end

    def self.test(name, &block)
      @tests << [name, block]
    end

    def self.next_test
      # Unused definitions that appeared during the previous test.
      if @cases.last
        model = Sketchup.active_model
        now = unused_new_definitions(model)
        fresh = now - (@unused_seen || [])
        @unused_seen = now
        @cases.last.note("unused definition(s) appeared: #{fresh.map(&:name).join(', ')}") unless fresh.empty?
      end
      if @tests.empty?
        finish
        return
      end
      name, block = @tests.shift
      c = Case.new(name)
      @cases << c
      Sketchup.status_text = "#{LOG} #{name}"
      guarded(c) { block.call(c, Sketchup.active_model) }
      schedule { next_phase(c) }
    end

    def self.next_phase(c)
      phase = c.phases.shift
      if phase.nil? || c.skipped
        next_test
        return
      end
      guarded(c) { phase.call }
      schedule { next_phase(c) }
    end

    def self.guarded(c)
      yield
    rescue => e
      c.check(false, "exception: #{e.class}: #{e.message}", e.backtrace.first(4).join(' | '))
      c.phases.clear
    end

    def self.fatal(e)
      @fatal = "#{e.class}: #{e.message} | #{e.backtrace.first(6).join(' | ')}"
      finish
    end

    # -------------------------------------------------------------------
    # Setup
    # -------------------------------------------------------------------

    PLUGIN_FILES = %w[
      version circle_restore/detector circle_restore/rebuilder circle_restore/volume
      circle_restore solid_operations procedural procedural_table highlight main procedural_observer
    ].freeze

    def self.plugin_dir
      File.join(SolidProcedural::PLUGIN_DIR, 'solid_progress')
    end

    def self.reload_plugin
      raise 'Solid Procedural is not loaded in this SketchUp' unless defined?(SolidProcedural::Procedural)
      # Constants are redefined: silence the "already initialized" warnings.
      verbose = $VERBOSE
      $VERBOSE = nil
      PLUGIN_FILES.each { |f| load File.join(plugin_dir, "#{f}.rb") }
    ensure
      $VERBOSE = verbose
    end

    # Message boxes recorded instead of shown; status texts recorded too.
    def self.hook
      tests = self
      ui = UI.singleton_class
      ui.send(:alias_method, :sp_tests_messagebox, :messagebox) unless ui.method_defined?(:sp_tests_messagebox)
      UI.define_singleton_method(:messagebox) do |*args|
        tests.messages << args.first.to_s
        1
      end
      su = Sketchup.singleton_class
      su.send(:alias_method, :sp_tests_status_text=, :status_text=) unless su.method_defined?(:sp_tests_status_text=)
      Sketchup.define_singleton_method(:status_text=) do |text|
        tests.status << text.to_s
        Sketchup.send(:sp_tests_status_text=, text)
      end
      su.send(:alias_method, :sp_tests_is_pro?, :is_pro?) unless su.method_defined?(:sp_tests_is_pro?)
      sp = SolidProcedural.singleton_class
      # Plugin methods: aliased again after each reload of the plugin.
      Procedural.singleton_class.send(:alias_method, :sp_tests_ruby_engine?, :ruby_engine?)
      CircleRestore::Volume.singleton_class.send(:alias_method, :sp_tests_repair_holes, :repair_holes)
      sp.send(:alias_method, :sp_tests_auto_repair_large, :auto_repair_large)
      @hooked = true
    end

    def self.unhook
      return unless @hooked
      UI.singleton_class.send(:alias_method, :messagebox, :sp_tests_messagebox)
      Sketchup.singleton_class.send(:alias_method, :status_text=, :sp_tests_status_text=)
      restore_pro
      restore_engine
      restore_repair
      restore_auto_repair
      @hooked = false
    end

    # Sketchup.is_pro? answers +value+ (SketchUp Make simulated in SketchUp
    # Pro).
    def self.force_pro(value)
      Sketchup.define_singleton_method(:is_pro?) { value }
    end

    def self.restore_pro
      Sketchup.singleton_class.send(:alias_method, :is_pro?, :sp_tests_is_pro?)
    end

    def self.force_engine(ruby)
      Procedural.define_singleton_method(:ruby_engine?) { ruby }
    end

    def self.restore_engine
      Procedural.singleton_class.send(:alias_method, :ruby_engine?, :sp_tests_ruby_engine?)
    end

    # Circles restored on large results too, whatever the Set Repair
    # Options of this PC.
    def self.force_auto_repair
      SolidProcedural.define_singleton_method(:auto_repair_large) { 'Yes' }
    end

    def self.restore_auto_repair
      SolidProcedural.singleton_class.send(:alias_method, :auto_repair_large, :sp_tests_auto_repair_large)
    end

    # Volume.repair_holes runs the former method (:scan, repair_holes_scan)
    # or the one of the plugin (:plugin), counting its calls, holes and time.
    def self.force_repair(mode)
      tests = self
      @repair_stats = { calls: 0, holes: 0, time: 0.0 }
      CircleRestore::Volume.define_singleton_method(:repair_holes) do |entities, holes, existing|
        stats = tests.repair_stats
        stats[:calls] += 1
        stats[:holes] += holes.length
        started = Time.now
        begin
          if mode == :scan
            tests.repair_holes_scan(entities, holes, existing)
          else
            CircleRestore::Volume.sp_tests_repair_holes(entities, holes, existing)
          end
        ensure
          stats[:time] += Time.now - started
        end
      end
    end

    def self.restore_repair
      CircleRestore::Volume.singleton_class.send(:alias_method, :repair_holes, :sp_tests_repair_holes)
    end

    def self.repair_stats
      @repair_stats
    end

    # Former Volume.repair_holes (Re-Cercle v2.0.0, Solid Procedural 1.1.0
    # and before), unchanged: every edge is scanned for every hole. Reference
    # of the T15 comparisons.
    def self.repair_holes_scan(entities, holes, existing)
      tol = CircleRestore::Detector::BASE_TOL * 10
      near = ->(p, h) { h.any? { |q| p.distance(q) < tol } }
      holes.each do |h|
        edge = entities.grep(Sketchup::Edge).find do |ed|
          near.call(ed.start.position, h) && near.call(ed.end.position, h)
        end
        edge.find_faces if edge
      end
      entities.grep(Sketchup::Face).each do |f|
        next if !f.valid? || existing[f.entityID]
        pts = f.outer_loop.vertices.map(&:position)
        filled = holes.any? do |h|
          h.length == pts.length && pts.all? { |p| near.call(p, h) }
        end
        f.erase! if filled
      end
    end

    # A new model, unsaved and unchanged, emptied of its template content.
    def self.prepare_model(attempt, &after)
      model = Sketchup.active_model
      if model.path.to_s.empty? && !model.modified?
        model.start_operation('Solid Procedural tests — setup', true)
        model.entities.erase_entities(model.entities.to_a) unless model.entities.length.zero?
        model.commit_operation
        model.selection.clear
        @definitions_before = model.definitions.to_a
        after.call
      elsif attempt < 3
        Sketchup.file_new
        schedule { prepare_model(attempt + 1, &after) }
      else
        raise 'No new empty model: close the current model and run the tests again'
      end
    end

    # -------------------------------------------------------------------
    # Geometry and queries
    # -------------------------------------------------------------------

    def self.pt(x, y, z)
      Geom::Point3d.new(x, y, z)
    end

    def self.box(entities, x, y, z, w, d, h, material = nil)
      g = entities.add_group
      f = g.entities.add_face(pt(x, y, z), pt(x + w, y, z), pt(x + w, y + d, z), pt(x, y + d, z))
      f.reverse! if f.normal.z < 0
      f.pushpull(h)
      g.material = material if material
      g
    end

    def self.cylinder(entities, cx, cy, z, r, h, material = nil, segments = 24)
      g = entities.add_group
      edges = g.entities.add_circle(pt(cx, cy, z), Z_AXIS, r, segments)
      f = g.entities.add_face(edges)
      f.reverse! if f.normal.z < 0
      f.pushpull(h)
      g.material = material if material
      g
    end

    def self.material(model, name, rgb)
      m = model.materials[name] || model.materials.add(name)
      m.color = Sketchup::Color.new(*rgb)
      m
    end

    def self.red(model)
      c = SolidProcedural.subtract_color
      material(model, 'SP Test Subtract', [c.red, c.green, c.blue])
    end

    def self.base_material(model)
      material(model, 'SP Test Base', [200, 180, 120])
    end

    def self.procedural_groups(model)
      model.entities.grep(Sketchup::Group).select { |g| Procedural.procedural?(g) }
    end

    def self.select(model, *entities)
      model.selection.clear
      model.selection.add(entities.flatten)
    end

    def self.arc_edges(entities)
      n = 0
      entities.each do |e|
        if e.is_a?(Sketchup::Edge)
          n += 1 if e.curve.is_a?(Sketchup::ArcCurve)
        elsif e.is_a?(Sketchup::Group)
          n += arc_edges(e.entities)
        elsif e.is_a?(Sketchup::ComponentInstance)
          n += arc_edges(e.definition.entities)
        end
      end
      n
    end

    def self.inner(instance)
      instance.is_a?(Sketchup::Group) ? instance.entities : instance.definition.entities
    end

    def self.green?(model)
      Highlight.green?(model.rendering_options['HighlightColor'])
    end

    def self.pro?
      Sketchup.is_pro?
    end

    # The edition check of Procedural.ruby_engine? and the line that sets
    # the plugin to SketchUp Pro only (commented out by default).
    PRO_TEST = 'ruby = !Sketchup.is_pro?'.freeze
    GUARD = 'raise ProOnly, __LINE__ if ruby'.freeze

    def self.procedural_path
      File.join(plugin_dir, 'procedural.rb')
    end

    def self.procedural_lines
      File.open(procedural_path, 'r:UTF-8', &:readlines)
    end

    # Index of the Pro only line in procedural.rb (commented or not), or nil.
    def self.guard_index(lines)
      lines.index { |l| l.strip.sub(/\A#\s*/, '') == GUARD }
    end

    # procedural.rb with the Pro only line uncommented, as a user would do.
    # Returns the number of that line. restore_procedural afterwards.
    def self.load_procedural_pro_only
      lines = procedural_lines
      k = guard_index(lines)
      lines[k] = lines[k].sub(/\A(\s*)#\s*/, '\1')
      verbose = $VERBOSE
      $VERBOSE = nil
      eval(lines.join, TOPLEVEL_BINDING, procedural_path, 1)
      k + 1
    ensure
      $VERBOSE = verbose
    end

    def self.restore_procedural
      verbose = $VERBOSE
      $VERBOSE = nil
      load procedural_path
    ensure
      $VERBOSE = verbose
    end

    def self.path_settable?(model)
      ProceduralTable.active_path_settable?(model)
    end

    def self.close_all(model)
      model.active_path = nil
    rescue ArgumentError, TypeError
      model.active_path = []
    end

    def self.unused_new_definitions(model)
      (model.definitions.to_a - (@definitions_before || [])).select do |d|
        d.valid? && !d.group? && d.count_instances.zero?
      end
    end

    def self.digest(file)
      require 'digest/md5'
      File.exist?(file) ? Digest::MD5.file(file).hexdigest : nil
    end

    # One group of cylinders along +axis, a base center at each point.
    def self.cylinders(entities, centers, axis, r, h, segments = 24)
      g = entities.add_group
      centers.each { |c| add_cylinder(g.entities, c, axis, r, h, segments) }
      g
    end

    def self.add_cylinder(entities, center, axis, r, h, segments = 24)
      f = entities.add_face(entities.add_circle(center, axis, r, segments))
      f.reverse! if f.normal.dot(axis) < 0
      f.pushpull(h)
    end

    # One group of truncated cones along +z: radius r1 at each point, r2 at h.
    def self.cones(entities, centers, r1, r2, h, segments = 24)
      g = entities.add_group
      centers.each do |c|
        add_cylinder(g.entities, c, Z_AXIS, r1, h, segments)
        top = pt(c.x, c.y, c.z + h)
        ring = g.entities.grep(Sketchup::Edge).select do |e|
          e.vertices.all? { |v| (v.position.z - top.z).abs < 1e-6 && v.position.distance(top) < r1 * 1.01 }
        end
        g.entities.transform_entities(Geom::Transformation.scaling(top, r2 / r1), ring)
      end
      g
    end

    # Specimens of two volumes in contact (T22).
    CONTACT_SPECIMENS = [
      'stacked boxes, same face', 'box on a plate', 'boxes side by side, same face',
      'boxes side by side, offset faces', 'boxes touching along an edge', 'cylinder on a plate',
      'tangent cylinders', 'disc in a pocket, same circle', 'disc in a pocket, 0.1 mm larger'
    ].freeze

    # [base, other] of the specimen +kind+ at (x, y). A red hole through
    # the base at (x + 4, y + 4) misses the other volume or its contact.
    def self.contact_specimen(kind, entities, x, y)
      case kind
      when 'stacked boxes, same face'
        [box(entities, x, y, 0, 10, 10, 10), box(entities, x, y, 10, 10, 10, 10)]
      when 'box on a plate'
        [box(entities, x, y, 0, 20, 20, 4), box(entities, x + 5, y + 5, 4, 10, 10, 10)]
      when 'boxes side by side, same face'
        [box(entities, x, y, 0, 10, 10, 10), box(entities, x + 10, y, 0, 10, 10, 10)]
      when 'boxes side by side, offset faces'
        [box(entities, x, y, 0, 10, 10, 10), box(entities, x + 10, y + 5, 0, 10, 10, 10)]
      when 'boxes touching along an edge'
        [box(entities, x, y, 0, 10, 10, 10), box(entities, x + 10, y + 10, 0, 10, 10, 10)]
      when 'cylinder on a plate'
        [box(entities, x, y, 0, 20, 20, 4), cylinder(entities, x + 10, y + 10, 4, 5, 10)]
      when 'tangent cylinders'
        [cylinder(entities, x + 5, y + 5, 0, 5, 10), cylinder(entities, x + 15, y + 5, 0, 5, 10)]
      when 'disc in a pocket, same circle' then pocket(entities, x, y, 0)
      when 'disc in a pocket, 0.1 mm larger' then pocket(entities, x, y, 0.1.mm)
      end
    end

    # A plate 20 x 20 x 4 with a pocket of radius 5, 2 deep, and a disc 4
    # high that fills it, +grow+ larger in radius.
    def self.pocket(entities, x, y, grow)
      plate = box(entities, x, y, 0, 20, 20, 4)
      circle = plate.entities.add_circle(pt(x + 10, y + 10, 4), Z_AXIS, 5, 24)
      circle.first.faces.min_by(&:area).pushpull(-2)
      [plate, cylinder(entities, x + 10, y + 10, 2, 5 + grow, 4)]
    end

    # Boolean of the plugin's engines (Procedural.combine): the solid that
    # holds the result, or nil.
    def self.boolean(ruby, op, acc, tool)
      return Procedural.ruby_boolean(op, acc, tool) if ruby
      op == 'union' ? acc.union(tool) : tool.subtract(acc)
    end

    # Geometry of a solid, independent of the order and IDs of its entities.
    def self.shape_signature(solid)
      ents = inner(solid)
      r = ->(v) { v.to_f.round(5) }
      name = ->(x) { x ? x.name : '' }
      faces = ents.grep(Sketchup::Face).map do |f|
        n = f.normal
        pts = f.vertices.map { |v| p = v.position; [r.call(p.x), r.call(p.y), r.call(p.z)] }.sort
        [r.call(f.area), [r.call(n.x), r.call(n.y), r.call(n.z)], name.call(f.material),
         name.call(f.back_material), f.layer.name, f.loops.length, pts]
      end
      edges = ents.grep(Sketchup::Edge)
      curves = edges.map(&:curve).compact.uniq
      {
        faces: faces.sort,
        edges: edges.length,
        soft: edges.count(&:soft?),
        smooth: edges.count(&:smooth?),
        arcs: curves.count { |cv| cv.is_a?(Sketchup::ArcCurve) },
        arc_edges: edges.count { |e| e.curve.is_a?(Sketchup::ArcCurve) },
        volume: solid.volume.round(4),
        manifold: solid.manifold?
      }
    end

    def self.signature_diff(a, b)
      keys = a.keys.select { |k| a[k] != b[k] }
      parts = keys.map do |k|
        next "#{k} #{a[k].inspect} / #{b[k].inspect}" unless k == :faces
        "faces #{a[:faces].length} / #{b[:faces].length}, former only: #{(a[:faces] - b[:faces]).first(2).inspect}, " \
          "plugin only: #{(b[:faces] - a[:faces]).first(2).inspect}"
      end
      parts.join('; ')[0, 800]
    end

    # -------------------------------------------------------------------
    # Tests
    # -------------------------------------------------------------------

    def self.define_tests
      tests = self

      test 'T01 Plugin loaded, installed copy = project' do |c, _model|
        c.check(defined?(SolidProcedural::VERSION), 'VERSION defined')
        c.note("plugin #{SolidProcedural::VERSION}, SketchUp #{Sketchup.version}, " \
               "Pro=#{Sketchup.is_pro?}, Ruby #{RUBY_VERSION}, union defined=#{Sketchup::Group.method_defined?(:union)}")
        c.check(Procedural.respond_to?(:remove_definition), 'Procedural.remove_definition defined')
        c.check(ProceduralTable.respond_to?(:active_path_settable?), 'ProceduralTable.active_path_settable? defined')
        project = File.join(tests::PROJECT_DIR, 'solid_progress')
        files = Dir.glob(File.join(project, '**', '*')).select { |f| File.file?(f) }
        different = files.reject do |f|
          tests.digest(f) == tests.digest(File.join(tests.plugin_dir, f[(project.length + 1)..-1]))
        end
        c.check(!files.empty? && different.empty?, "installed plugin identical to the project (#{files.length} files)",
                different.map { |f| f[(project.length + 1)..-1] }.join(', '))
        html = File.read(File.join(tests.plugin_dir, 'html', 'procedural_table.html'))
        c.check(html.include?('-webkit-user-select'), 'table page has -webkit-user-select')
        c.check(html.include?('id="finalize"'), 'table page has the Finalize button')
      end

      test 'T02 Create with one component volume (no boolean needed)' do |c, model|
        comp = tests.box(model.entities, 0, 0, 0, 10, 10, 10, tests.base_material(model)).to_component
        tests.select(model, comp)
        before = tests.procedural_groups(model).length
        tests.messages.clear
        Procedural.do_create
        c.check(tests.messages.empty?, 'no message', tests.messages.join(' / '))
        groups = tests.procedural_groups(model)
        c.check(groups.length == before + 1, 'one procedural solid created')
        g = groups.last
        next unless g
        @state[:single] = g
        result = Procedural.result_of(g)
        c.check(result && result.manifold?, 'Result is a solid')
        c.check(Procedural.sources_of(g).length == 1, 'one source volume')
        c.later do
          left = tests.unused_new_definitions(model)
          c.check(left.empty?, 'no unused component definition left',
                  left.map { |d| "#{d.name} (#{d.entities.length} entities)" }.join(', '))
        end
      end

      test 'T03 Display inside / outside' do |c, model|
        g = @state[:single]
        next c.skip('no procedural solid (T02)') unless g
        model.start_operation('Solid Procedural tests — display', true)
        Procedural.apply_display(g, true)
        model.commit_operation
        sources = Procedural.sources_of(g)
        result = Procedural.result_of(g)
        c.check(sources.none?(&:hidden?) && result.hidden?, 'inside: sources shown, Result hidden')
        model.start_operation('Solid Procedural tests — display', true)
        Procedural.apply_display(g, false)
        model.commit_operation
        c.check(sources.all?(&:hidden?) && !result.hidden?, 'outside: sources hidden, Result shown')
      end

      test 'T04 Procedural Table: rows, open and select a row' do |c, model|
        g = @state[:single]
        next c.skip('no procedural solid (T02)') unless g
        tests.select(model, g)
        payload = ProceduralTable.payload(model)
        c.check(payload[:group] == g.entityID, 'table shows the selected procedural solid')
        rows = payload[:rows] || []
        c.check(rows.length == 1 && rows[0][:base], 'one row, the base')
        next if rows.empty?
        tests.status.clear
        ProceduralTable.open_row(model, g, rows[0][:key])
        if tests.path_settable?(model)
          c.check((model.active_path || []).last == g, 'double-click on a row opens the procedural solid')
          c.later do
            c.check(Procedural.sources_of(g).none?(&:hidden?), 'opened: sources shown (observer)')
            c.check(model.selection.include?(Procedural.sources_of(g).first), 'opened: row volume selected')
            tests.close_all(model)
          end
          c.later do
            c.check(Procedural.result_of(g) && !Procedural.result_of(g).hidden?, 'closed: Result shown (observer)')
          end
        else
          c.check((model.active_path || []).empty?, 'no active_path=: the solid stays closed, no error')
          c.check(tests.status.any? { |s| s.include?('Double-click') }, 'no active_path=: message in the status bar',
                  tests.status.last.to_s)
          notice = ProceduralTable.payload(model)[:notice].to_s
          c.check(notice.include?('Double-click'), 'no active_path=: message in the table', notice)
          ProceduralTable.on_action({ type: 'toggle', group: g.entityID, key: rows[0][:key], on: true }.to_json)
          c.check(ProceduralTable.payload(model)[:notice].nil?, 'message cleared by the next table action')
        end
      end

      test 'T05 Circle restoration (native circles)' do |c, model|
        g = tests.cylinder(model.entities, 40, 0, 0, 3, 10)
        g.entities.grep(Sketchup::Edge).each { |e| e.explode_curve if e.valid? && e.curve }
        c.check(tests.arc_edges(g.entities).zero?, 'test cylinder has no circle left')
        edges = g.entities.grep(Sketchup::Edge).length
        model.start_operation('Solid Procedural tests — circles', true)
        res = CircleRestore.restore_in_solid(g, min_arc_segments: 6)
        model.commit_operation
        c.note("restore: #{CircleRestore.summary(res, reasons: true)}")
        c.check(res[:native] >= 2, "native circles rebuilt (#{res[:native]})")
        c.check(tests.arc_edges(g.entities) == 48, "48 edges in native circles (#{tests.arc_edges(g.entities)})")
        c.check(g.manifold? && g.entities.grep(Sketchup::Edge).length == edges, 'still a solid, same edges')
      end

      test 'T06 Create with a base and a subtract volume' do |c, model|
        base = tests.box(model.entities, 0, 30, 0, 10, 10, 10, tests.base_material(model))
        hole = tests.cylinder(model.entities, 5, 35, -2, 2, 14, tests.red(model))
        base_volume = base.volume
        tests.select(model, base, hole)
        before = tests.procedural_groups(model).length
        tests.messages.clear
        Procedural.do_create
        groups = tests.procedural_groups(model)
        c.note("engine: #{Procedural.ruby_engine? ? 'SketchUp Make (Ruby)' : 'native'}")
        c.check(tests.messages.empty?, 'no message', tests.messages.join(' / '))
        c.check(groups.length == before + 1, 'procedural solid created')
        g = groups.last
        next unless g && groups.length == before + 1
        @state[:pair] = g
        result = Procedural.result_of(g)
        c.check(result && result.manifold?, 'Result is a solid')
        next unless result
        c.check(result.volume < base_volume - 1, "hole subtracted (#{result.volume.round(2)} < #{base_volume.round(2)})")
        c.check(result.material == tests.base_material(model), 'Result has the material of the base',
                "Result: #{result.material ? result.material.name : 'none'}")
        c.check(tests.inner(result).grep(Sketchup::Face).none? { |f| Procedural.subtract_material?(f.material) },
                'no face of the subtract color')
        c.check(tests.arc_edges(tests.inner(result)) > 0, 'native circles on the Result')
        c.check(Procedural.sources_of(g).all?(&:hidden?), 'sources hidden outside')
        others = g.entities.to_a - Procedural.sources_of(g) - [result]
        c.check(others.empty?, 'nothing else left in the group', others.map { |e| e.class.name }.join(', '))
      end

      test 'T07 Automatic rebuild when the solid is closed' do |c, model|
        g = @state[:pair]
        next c.skip('needs SketchUp Pro (booleans)') unless g
        next c.skip('needs Model#active_path= (SketchUp 2020+)') unless tests.path_settable?(model)
        volume = Procedural.result_of(g).volume
        model.active_path = [g]
        c.later do
          hole = Procedural.sources_of(g).last
          c.check(!hole.hidden?, 'opened: sources shown')
          model.start_operation('Solid Procedural tests — move the hole', true)
          hole.transform!(Geom::Transformation.translation(Geom::Vector3d.new(5, 0, 0)))
          model.commit_operation
          tests.close_all(model)
        end
        c.later do
          result = Procedural.result_of(g)
          c.check(result && !result.hidden?, 'closed: Result shown')
          c.check(result && result.volume > volume + 1, "rebuilt: half of the hole is outside (#{result.volume.round(2)} > #{volume.round(2)})")
          c.check(!Procedural.stale?(g), 'signature up to date')
        end
      end

      test 'T08 Rebuild command' do |c, model|
        g = @state[:pair] || @state[:single]
        next c.skip('no procedural solid') unless g
        tests.select(model, g)
        tests.messages.clear
        Procedural.do_rebuild
        c.check(tests.messages.empty?, 'no message', tests.messages.join(' / '))
        c.check(Procedural.result_of(g) && Procedural.result_of(g).manifold?, 'Result is a solid')
        c.check(model.selection.include?(g), 'procedural solid still selected')
      end

      test 'T08b Rebuild one component volume, undo, redo' do |c, model|
        g = @state[:single]
        next c.skip('no procedural solid (T02)') unless g
        before = tests.unused_new_definitions(model)
        old_definition = Procedural.result_of(g).definition
        tests.select(model, g)
        tests.messages.clear
        Procedural.do_rebuild
        c.check(tests.messages.empty?, 'no message', tests.messages.join(' / '))
        result = Procedural.result_of(g)
        c.check(result && result.manifold? && result.definition != old_definition, 'new Result, a solid')
        left = tests.unused_new_definitions(model) - before
        c.check(left.empty?, 'former Result definition not left unused', left.map(&:name).join(', '))
        next unless Sketchup.respond_to?(:undo)
        Sketchup.undo
        c.later do
          back = Procedural.result_of(g)
          c.check(back && back.valid? && back.manifold?, 'Ctrl+Z: former Result back, a solid')
          c.note("Ctrl+Z: same definition object = #{back && old_definition.valid? && back.definition == old_definition}")
          c.check(back && back.definition.entities.length > 0, 'Ctrl+Z: its definition has its geometry')
          Sketchup.send_action('editRedo:')
        end
        c.later do
          again = Procedural.result_of(g)
          c.check(again && again.valid? && again.manifold? && again.definition != old_definition,
                  'Ctrl+Y: new Result back')
          left = tests.unused_new_definitions(model) - before
          c.check(left.empty?, 'Ctrl+Y: no unused definition', left.map(&:name).join(', '))
        end
      end

      test 'T09 Finalize a copy, selection color, undo' do |c, model|
        g = @state[:pair] || @state[:single]
        next c.skip('no procedural solid') unless g
        # As Ctrl+C / Ctrl+V or Move + Ctrl: a new instance of the same
        # definition with the attributes of the instance (Group#copy makes
        # the definition unique and drops the attributes and the material).
        model.start_operation('Solid Procedural tests — copy', true)
        copy = model.entities.add_instance(g.definition,
                                           Geom::Transformation.translation(Geom::Vector3d.new(0, 60, 0)) * g.transformation)
        c.note("add_instance: shared definition right after = #{copy.definition == g.definition}")
        dict = g.attribute_dictionary(Procedural::DICT)
        dict.each_pair { |k, v| copy.set_attribute(Procedural::DICT, k, v) } if dict
        # No copy.name=: Group#name= makes the definition unique.
        model.commit_operation
        c.check(copy.definition == g.definition, 'the copy shares the definition of the original',
                "original #{g.definition.name} (#{g.definition.count_instances} instance(s)), "                 "copy #{copy.definition.name} (#{copy.class.name})")
        c.check(Procedural.procedural?(copy), 'the copy is a procedural solid')
        tests.select(model, copy)
        c.later do
          c.check(tests.green?(model), 'procedural solid selected: green frame')
          @state[:count] = tests.procedural_groups(model).length
          tests.messages.clear
          Procedural.do_finalize
          c.check(tests.messages.empty?, 'Finalize: no message', tests.messages.join(' / '))
          solid = model.selection.first
          c.check(!copy.valid?, 'copy replaced')
          c.check(solid && Procedural.instance?(solid) && !Procedural.procedural?(solid) && solid.manifold?,
                  'plain solid selected')
          c.check(Procedural.procedural?(g) && Procedural.result_of(g) && Procedural.sources_of(g).length >= 1,
                  'original procedural solid intact')
        end
        c.later do
          c.check(!tests.green?(model), 'after Finalize: frame no longer green')
          if Sketchup.respond_to?(:undo)
            Sketchup.undo
          else
            c.note('Sketchup.undo not available: undo not tested')
          end
        end
        c.later do
          next unless Sketchup.respond_to?(:undo)
          c.check(tests.procedural_groups(model).length == @state[:count], 'Ctrl+Z: the procedural copy is back')
          model.selection.clear
        end
        c.later do
          c.check(!tests.green?(model), 'nothing selected: frame not green')
        end
      end

      # T10: one SketchUp edition check in the whole plugin, and one line,
      # commented out by default, that sets the plugin to SketchUp Pro only.
      # Uncommented (in a loaded copy of procedural.rb), without Pro: Create,
      # Rebuild, Finalize, the rebuild (automatic or from the Procedural
      # Table) show the message that names that line, and nothing is
      # changed. In SketchUp Pro, SketchUp Make is simulated.
      test 'T10 One edition check; the Pro only line (commented out by default)' do |c, model|
        files = Dir.glob(File.join(tests.plugin_dir, '**', '*.rb')) +
                [File.join(SolidProcedural::PLUGIN_DIR, 'solid_progress.rb')]
        hits = []
        texts = []
        files.each do |f|
          File.open(f, 'r:UTF-8', &:readlines).each_with_index do |l, k|
            hits << "#{File.basename(f)}:#{k + 1}" if l.include?('is_pro?')
            texts << "#{File.basename(f)}:#{k + 1}" if l =~ /requires SketchUp Pro|PRO_ONLY|pro_only\?/
          end
        end
        c.check(hits.length == 1, "Sketchup.is_pro? tested once in the #{files.length} plugin files", hits.join(', '))
        c.check(texts.empty?, 'no former Pro message or switch', texts.join(', '))
        lines = tests.procedural_lines
        k = tests.guard_index(lines)
        c.check(k && lines.count { |l| l.strip.sub(/\A#\s*/, '') == tests::GUARD } == 1, 'one Pro only line')
        next unless k
        c.check(lines[k].strip.start_with?('#'), 'commented out by default: the plugin works without Pro',
                lines[k].strip)
        c.check(lines[k - 1].strip == tests::PRO_TEST, 'just after the edition check', lines[k - 1].strip)
        base = tests.box(model.entities, 0, 90, 0, 10, 10, 10)
        tests.select(model, base)
        before = tests.procedural_groups(model).length
        g = @state[:pair]
        begin
          line = tests.load_procedural_pro_only
          tests.force_pro(false)
          want = "PRO Only vs. procedural.rb:#{line}"
          tests.messages.clear
          Procedural.do_create
          c.check(tests.messages == [want], "Create: #{want} (the Pro only line)", tests.messages.inspect)
          c.check(tests.procedural_groups(model).length == before && base.parent == model, 'Create: nothing created')
          if g && g.valid? && Procedural.result_of(g)
            sig = g.get_attribute(Procedural::DICT, 'signature')
            volume = Procedural.result_of(g).volume
            %w[do_rebuild do_finalize].each do |command|
              tests.select(model, g)
              tests.messages.clear
              Procedural.send(command)
              c.check(tests.messages == [want], "#{command}: #{want}", tests.messages.inspect)
            end
            error = begin
              Procedural.rebuild_in_operation(model, g)
              nil
            rescue Procedural::RebuildError => e
              e
            end
            c.check(error.is_a?(Procedural::ProOnly) && error.message == want,
                    "rebuild (automatic, on exit): #{want}", error ? "#{error.class}: #{error.message}" : 'no error')
            key = Procedural.row_keys(Procedural.sources_of(g)).last
            tests.messages.clear
            Procedural.table_toggle(model, g, key, false)
            c.check(tests.messages.length == 1 && tests.messages[0].include?(want),
                    "Procedural Table, disable a volume: #{want}", tests.messages.inspect)
            c.check(Procedural.enabled?(Procedural.sources_of(g).last), 'Procedural Table: the volume is still enabled')
            result = Procedural.result_of(g)
            c.check(Procedural.procedural?(g) && result && (result.volume - volume).abs < 0.001 &&
                    g.get_attribute(Procedural::DICT, 'signature') == sig && !Procedural.stale?(g),
                    'procedural solid unchanged (Result, signature)')
          else
            c.note('no procedural solid (T06): Rebuild, Finalize and the Procedural Table not tested')
          end
        ensure
          tests.restore_procedural
          tests.restore_pro
        end
        # procedural.rb loaded again: without Pro, the Ruby engine, no message.
        tests.force_pro(false)
        restored = begin
          Procedural.ruby_engine? == true
        rescue Procedural::ProOnly
          false
        ensure
          tests.restore_pro
        end
        c.check(restored && Sketchup.is_pro? == Sketchup.sp_tests_is_pro?, 'procedural.rb and Sketchup.is_pro? restored')
      end

      test 'T13 Finalize button of the Procedural Table' do |c, model|
        base = tests.box(model.entities, 0, 120, 0, 10, 10, 10, tests.base_material(model))
        hole = tests.cylinder(model.entities, 5, 125, -2, 2, 14, tests.red(model))
        tests.select(model, base, hole)
        tests.messages.clear
        Procedural.do_create
        g = tests.procedural_groups(model).last
        next c.check(false, 'procedural solid created', tests.messages.join(' / ')) unless g
        @state[:count] = tests.procedural_groups(model).length
        if tests.path_settable?(model)
          model.active_path = [g]
          ProceduralTable.on_action({ type: 'finalize', group: g.entityID }.to_json)
          c.check(g.valid? && Procedural.procedural?(g), 'open: not finalized')
          notice = ProceduralTable.payload(model)[:notice].to_s
          c.check(notice.include?('Close the Solid Progress group'), 'open: message in the table', notice)
          tests.close_all(model)
        else
          c.note('open case not tested: no Model#active_path=')
        end
        c.later do
          tests.select(model, g)
          tests.messages.clear
          ProceduralTable.on_action({ type: 'finalize', group: g.entityID }.to_json)
          c.check(tests.messages.empty?, 'closed: no message', tests.messages.join(' / '))
          solid = model.selection.first
          c.check(!g.valid?, 'closed: procedural solid replaced')
          c.check(solid && Procedural.instance?(solid) && !Procedural.procedural?(solid) && solid.manifold?,
                  'closed: plain solid selected')
          c.check(tests.procedural_groups(model).length == @state[:count] - 1, 'one procedural solid less')
          Sketchup.undo if Sketchup.respond_to?(:undo)
        end
        c.later do
          next unless Sketchup.respond_to?(:undo)
          c.check(tests.procedural_groups(model).length == @state[:count], 'Ctrl+Z: the procedural solid is back')
          model.selection.clear
        end
      end

      # T12: volumes known in advance, for each engine (both in SketchUp
      # Pro, the Ruby engine forced for the second run; Ruby only in Make).
      hole_volume = 0.5 * 24 * 2 * 2 * Math.sin(2 * Math::PI / 24) * 10
      cases = [
        ['through hole', 1000 - hole_volume, nil, lambda do |m, x, y|
          [tests.box(m.entities, x, y, 0, 10, 10, 10, tests.base_material(m)),
           tests.cylinder(m.entities, x + 5, y + 5, -2, 2, 14, tests.red(m))]
        end],
        ['union of offset boxes', 1750, nil, lambda do |m, x, y|
          [tests.box(m.entities, x, y, 0, 10, 10, 10, tests.base_material(m)),
           tests.box(m.entities, x + 5, y + 5, 0, 10, 10, 10)]
        end],
        ['corner notch, coplanar faces', 840, nil, lambda do |m, x, y|
          [tests.box(m.entities, x, y, 0, 10, 10, 10, tests.base_material(m)),
           tests.box(m.entities, x - 1, y - 1, 0, 5, 5, 10, tests.red(m))]
        end],
        # Native Outer Shell keeps a solid enclosed in another (1000 + 4^3);
        # the Ruby engine erases it (Solid for Maker remove_cavities).
        ['shell with an inner box', { false => 1064, true => 1000 }, 'outer_shell', lambda do |m, x, y|
          [tests.box(m.entities, x, y, 0, 10, 10, 10, tests.base_material(m)),
           tests.box(m.entities, x + 3, y + 3, 3, 4, 4, 4)]
        end],
        ['union then hole, coplanar faces', 1500 - hole_volume, nil, lambda do |m, x, y|
          [tests.box(m.entities, x, y, 0, 10, 10, 10, tests.base_material(m)),
           tests.box(m.entities, x + 5, y, 0, 10, 10, 10),
           tests.cylinder(m.entities, x + 10, y + 5, -2, 2, 14, tests.red(m))]
        end],
        # 20 subtract volumes; the 40 circles must all be native (repair_holes).
        ['plate with 20 holes', 2560 - 20 * 0.5 * 24 * 0.8 * 0.8 * Math.sin(2 * Math::PI / 24) * 2, nil,
         lambda do |m, x, y|
           [tests.box(m.entities, x, y, 0, 40, 32, 2, tests.base_material(m))] +
             (0...5).flat_map do |a|
               (0...4).map { |b| tests.cylinder(m.entities, x + 4 + 8 * a, y + 4 + 8 * b, -1, 0.8, 4, tests.red(m)) }
             end
         end, 40 * 24]
      ]
      engines = tests.pro? ? [false, true] : [true]
      engines.each_with_index do |ruby, e|
        cases.each_with_index do |(name, expected, second_op, build, arcs), i|
          label = ruby ? 'Ruby engine' : 'native'
          test "T12 #{label}: #{name}" do |c, model|
            tests.force_engine(ruby)
            tests.force_auto_repair if arcs
            begin
              volumes = build.call(model, i * 40, 200 + e * 40)
              holes = volumes.count { |v| tests.inner(v).grep(Sketchup::Edge).any?(&:curve) }
              tests.select(model, volumes)
              before = tests.procedural_groups(model).length
              tests.messages.clear
              started = Time.now
              Procedural.do_create
              groups = tests.procedural_groups(model)
              c.check(tests.messages.empty? && groups.length == before + 1, 'created without message',
                      tests.messages.join(' / '))
              g = groups.last
              next unless g && groups.length == before + 1
              if second_op
                tests.select(model, g)
                key = ProceduralTable.payload(model)[:rows][1][:key]
                Procedural.table_operation(model, g, key, second_op)
                c.check(Procedural.op_of(Procedural.sources_of(g)[1]) == second_op, "row 2 set to #{second_op}")
                c.check(tests.messages.empty?, 'no message', tests.messages.join(' / '))
              end
              c.note(format('time %.2fs', Time.now - started))
              result = Procedural.result_of(g)
              c.check(result && result.manifold?, 'Result is a solid')
              next unless result
              wanted = expected.is_a?(Hash) ? expected[ruby] : expected
              c.check((result.volume - wanted).abs < 0.01,
                      format('volume %.4f (expected %.4f)', result.volume, wanted))
              # The base is the first added volume in the group's order.
              c.check(result.material == Procedural.sources_of(g).first.material, 'material of the base')
              c.check(tests.inner(result).grep(Sketchup::Face).none? { |f| Procedural.subtract_material?(f.material) },
                      'no face of the subtract color')
              c.check(tests.arc_edges(tests.inner(result)) > 0, 'native circles') if holes > 0
              if arcs
                n = tests.arc_edges(tests.inner(result))
                c.check(n == arcs, "#{n} edges in native circles (expected #{arcs})")
              end
              others = g.entities.to_a - Procedural.sources_of(g) - [result]
              c.check(others.empty?, 'nothing else left in the group', others.map { |x| x.class.name }.join(', '))
            ensure
              tests.restore_engine
              tests.restore_auto_repair
            end
          end
        end
      end

      # T15: Volume.repair_holes of the plugin against the former method
      # (repair_holes_scan) on the same broken circles: same faces, edges and
      # circles expected (OPTIMISATION_REPAIR_HOLES.md, § 7).
      test 'T15 Grids of repair_holes = full scan' do |c, _model|
        vol = CircleRestore::Volume
        next c.skip('grid search not in the plugin yet') unless vol.respond_to?(:near_items)
        tol = CircleRestore::Detector::BASE_TOL * 10
        srand(1234)
        rnd = -> { (rand - 0.5) * 0.1 }
        # Dense points (many neighbors), negative coordinates, cell borders.
        points = Array.new(500) { tests.pt(rnd.call, rnd.call, rnd.call) }
        points += Array.new(50) { |k| tests.pt(tol * (k - 25), -tol * 3, tol * 2) }
        queries = Array.new(2000) { tests.pt(rnd.call, rnd.call, rnd.call) }
        queries += Array.new(200) { |k| tests.pt(tol * (k % 50 - 25) + rnd.call * 0.1, -tol * 3, tol * 2) }
        holder = Struct.new(:position)
        vertices = points.map { |p| holder.new(p) }
        grid = vol.point_grid(points, tol)
        vertex_grid = {}
        vertices.each { |v| (vertex_grid[vol.cell_of(v.position, tol)] ||= []) << v }
        bad = 0
        pairs = 0
        queries.each do |q|
          want = points.select { |p| q.distance(p) < tol }
          pairs += want.length
          got = vol.near_items(q, grid, tol)
          got_v = vol.near_items(q, vertex_grid, tol) { |v| v.position }.map(&:position)
          bad += 1 unless [got, got_v].all? { |list| list.map(&:object_id).sort == want.map(&:object_id).sort }
          bad += 1 unless vol.near_grid?(q, grid, tol) == !want.empty?
        end
        c.note("#{queries.length} queries, #{pairs} pairs closer than the tolerance")
        c.check(pairs > 1000, 'enough close pairs to test')
        c.check(bad.zero?, "same neighbors as the full scan (#{bad} difference(s))")
      end

      repair_cases = [
        ['plate with 20 holes', lambda do |m, x, y|
          centers = (0...5).flat_map { |i| (0...4).map { |j| tests.pt(x + 4 + 8 * i, y + 4 + 8 * j, -1) } }
          [tests.box(m.entities, x, y, 0, 40, 32, 2),
           [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 0.8, 4)]]]
        end],
        ['holes near an edge', lambda do |m, x, y|
          centers = [[1.15, 5], [5, 1.2], [10, 5], [15, 5]].map { |a, b| tests.pt(x + a, y + b, -1) }
          [tests.box(m.entities, x, y, 0, 20, 10, 2),
           [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 1, 4)]]]
        end],
        ['colored faces (front / back)', lambda do |m, x, y|
          base = tests.box(m.entities, x, y, 0, 20, 20, 2)
          base.entities.grep(Sketchup::Face).each do |f|
            if f.normal.z > 0.9
              f.material = tests.material(m, 'SP Test Top', [220, 60, 60])
              f.back_material = tests.material(m, 'SP Test Top back', [60, 60, 220])
            elsif f.normal.z < -0.9
              f.material = tests.material(m, 'SP Test Bottom', [60, 200, 60])
            elsif f.normal.x < -0.9
              f.material = tests.material(m, 'SP Test Side', [200, 200, 60])
            end
          end
          centers = [[5, 5], [15, 5], [5, 15], [15, 15]].map { |a, b| tests.pt(x + a, y + b, -1) }
          [base, [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 1, 4)]]]
        end],
        ['holes across two coplanar faces', lambda do |m, x, y|
          base = tests.box(m.entities, x, y, 0, 20, 10, 2)
          base.entities.add_line(tests.pt(x + 10, y, 2), tests.pt(x + 10, y + 10, 2))
          base.entities.add_line(tests.pt(x + 10, y, 0), tests.pt(x + 10, y + 10, 0))
          centers = [[10, 3], [10, 7], [4, 5], [4, 8], [16, 5], [16, 2]].map { |a, b| tests.pt(x + a, y + b, -1) }
          [base, [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 1, 4)]]]
        end],
        ['very small holes (1 mm)', lambda do |m, x, y|
          centers = [[1, 1], [2, 1], [3, 1], [1, 3], [2, 3], [3, 3]].map { |a, b| tests.pt(x + a, y + b, -0.2) }
          [tests.box(m.entities, x, y, 0, 4, 4, 0.4),
           [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 0.02, 0.8)]]]
        end],
        ['very large holes', lambda do |m, x, y|
          centers = [[50, 50], [150, 50], [50, 150], [150, 150]].map { |a, b| tests.pt(x + a, y + b, -1) }
          [tests.box(m.entities, x, y, 0, 200, 200, 4),
           [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 40, 6)]]]
        end],
        # The counterbore floor holds the hole circle.
        ['counterbores', lambda do |m, x, y|
          holes = [5, 12, 19].map { |a| tests.pt(x + a, y + 5, -1) }
          bores = holes.map { |p| tests.pt(p.x, p.y, 2) }
          [tests.box(m.entities, x, y, 0, 24, 10, 3),
           [['subtract', tests.cylinders(m.entities, bores, Z_AXIS, 2, 2)],
            ['subtract', tests.cylinders(m.entities, holes, Z_AXIS, 1, 5)]]]
        end],
        # Cone of radius 1.2 at z = 2 (a step around the hole), 2.2 at the top.
        ['countersinks with a step', lambda do |m, x, y|
          holes = [5, 12, 19].map { |a| tests.pt(x + a, y + 5, -1) }
          sinks = holes.map { |p| tests.pt(p.x, p.y, 2) }
          [tests.box(m.entities, x, y, 0, 24, 10, 3),
           [['subtract', tests.cones(m.entities, sinks, 1.2, 2.7, 1.5)],
            ['subtract', tests.cylinders(m.entities, holes, Z_AXIS, 1, 5)]]]
        end],
        # Hole first: the counterbore cuts the top face around the hole
        # (Solid for Maker 1.0.1, wrapping_face).
        ['counterbores after the holes', lambda do |m, x, y|
          holes = [5, 12, 19].map { |a| tests.pt(x + a, y + 5, -1) }
          bores = holes.map { |p| tests.pt(p.x, p.y, 2) }
          [tests.box(m.entities, x, y, 0, 24, 10, 3),
           [['subtract', tests.cylinders(m.entities, holes, Z_AXIS, 1, 5)],
            ['subtract', tests.cylinders(m.entities, bores, Z_AXIS, 2, 2)]]]
        end],
        ['holes on the top and on a side', lambda do |m, x, y|
          top = [[5, 5], [15, 5], [5, 15], [15, 15]].map { |a, b| tests.pt(x + a, y + b, -1) }
          side = [3, 7].map { |h| tests.pt(x - 1, y + 10, h) }
          [tests.box(m.entities, x, y, 0, 20, 20, 10),
           [['subtract', tests.cylinders(m.entities, top, Z_AXIS, 1, 12)],
            ['subtract', tests.cylinders(m.entities, side, X_AXIS, 1, 22)]]]
        end],
        ['truncated cones', lambda do |m, x, y|
          cones = [[5, 5], [15, 5], [5, 15]].map { |a, b| tests.pt(x + a, y + b, -1) }
          [tests.box(m.entities, x, y, 0, 20, 20, 3),
           [['subtract', tests.cones(m.entities, cones, 1.5, 0.7, 5)],
            ['subtract', tests.cylinders(m.entities, [tests.pt(x + 15, y + 15, -1)], Z_AXIS, 1, 5)]]]
        end],
        ['pins added by union (one end broken)', lambda do |m, x, y|
          centers = [[5, 5], [15, 5], [5, 15], [15, 15]].map { |a, b| tests.pt(x + a, y + b, 1) }
          [tests.box(m.entities, x, y, 0, 20, 20, 2),
           [['union', tests.cylinders(m.entities, centers, Z_AXIS, 1, 4)]]]
        end],
        ['blind holes', lambda do |m, x, y|
          centers = [[5, 5], [15, 5], [5, 15], [15, 15]].map { |a, b| tests.pt(x + a, y + b, 2) }
          [tests.box(m.entities, x, y, 0, 20, 20, 4),
           [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 1, 3)]]]
        end]
      ]
      engines.each_with_index do |ruby, e|
        repair_cases.each_with_index do |(name, build), i|
          label = ruby ? 'Ruby engine' : 'native'
          test "T15 #{label}: #{name}" do |c, model|
            base, steps = build.call(model, i * 250, 1000 + e * 250)
            definitions = model.definitions.to_a
            acc = base
            failed = nil
            steps.each_with_index do |(op, tool), k|
              acc = tests.boolean(ruby, op, acc, tool)
              next if acc && acc.valid?
              failed = "#{op} #{k + 1} of #{steps.length}"
              break
            end
            # Native booleans with a tool of several solids leave unused
            # definitions (TempInstance#n): removed here, T11 checks the plugin.
            temp = (model.definitions.to_a - definitions).select { |d| !d.group? && d.count_instances.zero? }
            unless temp.empty?
              c.note("the boolean left #{temp.length} unused definition(s) #{temp.first.name}... (removed by the test)")
              temp.each { |d| Procedural.remove_definition(model, d) }
            end
            next c.check(false, "boolean #{failed} failed") if failed
            c.check(acc.manifold?, 'boolean result is a solid')
            broken = tests.arc_edges(tests.inner(acc))
            sig = {}
            counts = {}
            stats = {}
            times = {}
            [:scan, :plugin].each do |mode|
              tests.force_repair(mode)
              model.start_operation('Solid Procedural tests — repair_holes', true)
              begin
                started = Time.now
                res = CircleRestore.restore_in_solid(acc, min_arc_segments: SolidProcedural.min_arc_segments)
                times[mode] = Time.now - started
                sig[mode] = tests.shape_signature(acc)
                counts[mode] = [res[:native], res[:welded], res[:unwelded], res[:reasons].to_a.sort]
                stats[mode] = tests.repair_stats.dup
                c.note("restore: #{CircleRestore.summary(res, reasons: true)}") if mode == :plugin
              ensure
                model.abort_operation
                tests.restore_repair
              end
            end
            c.check(stats[:scan][:holes] > 0,
                    "repair_holes used (#{stats[:scan][:calls]} calls, #{stats[:scan][:holes]} holes)")
            c.check(sig[:scan] == sig[:plugin], 'same faces, edges and circles as the former method',
                    tests.signature_diff(sig[:scan], sig[:plugin]))
            c.check(counts[:scan] == counts[:plugin], 'same restore counts',
                    "#{counts[:scan].inspect} / #{counts[:plugin].inspect}")
            c.check(stats[:scan].values_at(:calls, :holes) == stats[:plugin].values_at(:calls, :holes),
                    'same repair_holes calls')
            c.check(counts[:plugin][0] > 0 && sig[:plugin][:manifold], 'native circles rebuilt, still a solid',
                    counts[:plugin].inspect)
            c.note(format('arc edges before %d, after %d; restore: former %.2fs (repair_holes %.2fs), ' \
                          'plugin %.2fs (repair_holes %.2fs)', broken, sig[:plugin][:arc_edges],
                          times[:scan], stats[:scan][:time], times[:plugin], stats[:plugin][:time]))
            if i.zero? && CircleRestore::Volume.respond_to?(:near_items)
              c.check(stats[:plugin][:time] < stats[:scan][:time] / 2, 'plugin repair_holes at least twice faster')
            end
          end
        end
      end

      # T16: the plugin shows the name Solid Progress (2.0.0); "procedural"
      # is left only in identifiers the user never sees.
      test 'T16 Visible names: Solid Progress' do |c, model|
        c.check(SolidProcedural::PLUGIN_NAME == 'Solid Progress', 'PLUGIN_NAME is Solid Progress',
                SolidProcedural::PLUGIN_NAME)
        names = []
        Sketchup.extensions.each { |e| names << e.name }
        ext = Sketchup.extensions['Solid Progress']
        c.check(ext && ext.loaded?, 'extension Solid Progress registered and loaded')
        c.check(!names.include?('Solid Procedural'), 'no extension Solid Procedural (former name)')
        plugins = SolidProcedural::PLUGIN_DIR
        c.check(!File.exist?(File.join(plugins, 'solid_procedural.rb')) &&
                !File.exist?(File.join(plugins, 'solid_procedural')), 'former files not installed')
        c.check(Procedural::DEFAULT_NAME == 'Solid Progress' &&
                Procedural::SUBTRACT_MATERIAL_NAME == 'Solid Progress Subtract', 'default group and material names')
        # Identifiers kept on purpose: file names, registry, model dictionary
        # and role, table window key, JavaScript namespace.
        allowed = /\A(procedural|procedural_table|procedural_observer|procedural_table\.html|SolidProcedural|
                      SolidProcedural_ProceduralTable|SolidProcedural\.update\(|\w+_procedural_(16|24)\.png)\z/x
        begin
          require 'ripper'
          files = Dir.glob(File.join(tests.plugin_dir, '**', '*.rb')) + [File.join(plugins, 'solid_progress.rb')]
          visible = []
          files.each do |f|
            Ripper.lex(File.open(f, 'r:UTF-8', &:read)).each do |(line, _col), type, tok|
              next unless type == :on_tstring_content && tok =~ /procedural/i && tok.strip !~ allowed
              visible << "#{File.basename(f)}:#{line} #{tok.strip[0, 40]}"
            end
          end
          c.check(visible.empty?, "no visible \"procedural\" in the strings of #{files.length} files", visible.join(', '))
        rescue LoadError
          c.note('Ripper not available: strings of the code not scanned')
        end
        html = File.open(File.join(tests.plugin_dir, 'html', 'procedural_table.html'), 'r:UTF-8', &:readlines)
        left = html.each_with_index.reject do |l, _k|
          l !~ /procedural/i || l.strip.start_with?('//') || l.include?('window.SolidProcedural')
        end
        c.check(left.empty?, 'no visible "procedural" in the table page', left.map { |_l, k| k + 1 }.join(', '))
        c.check(html.join.include?('<title>Progress Table</title>'), 'table page title: Progress Table')
        model.selection.clear
        tests.messages.clear
        Procedural.do_rebuild
        c.check(tests.messages.length == 1 && tests.messages[0].include?('Solid Progress group'),
                'Rebuild without selection: message names Solid Progress groups', tests.messages.inspect)
      end

      # The demo model of tools/demo, built with the engine of this
      # SketchUp; the changes shown in the video, then undone by the table.
      test 'T17 Demo model builds (tools/demo)' do |c, model|
        $sp_demo_no_autorun = true
        begin
          load File.join(tests::PROJECT_DIR, 'tools', 'demo', 'build_demo.rb')
        ensure
          $sp_demo_no_autorun = nil
        end
        demo = SolidProcedural::Demo
        # Circles restored whatever the Set Repair Options of this PC.
        tests.force_auto_repair
        tests.messages.clear
        started = Time.now
        # Far from the other tests (the demo is in meters), and behind the
        # camera of its scenes.
        parts = demo.build(model, tests.pt(0, 10_000, 0))
        c.note(format('built in %.1f s', Time.now - started))
        c.check(tests.messages.empty?, 'no message', tests.messages.join(' / '))
        raw = parts[:raw]
        c.check(raw.map(&:name) == demo::PLATE_ORDER && raw.all?(&:manifold?) &&
                raw.none? { |v| Procedural.procedural?(v) }, 'scene 1: plate, pin and hole, solids, not grouped')
        plate = parts[:plate]
        r = Procedural.result_of(plate)
        c.check(r && r.manifold? && !r.hidden? && !Procedural.stale?(plate) &&
                Procedural.sources_of(plate).all?(&:hidden?), 'scene 2: Result solid, shown, up to date; sources hidden')
        c.check(Procedural.sources_of(plate).map(&:name) == demo::PLATE_ORDER, 'scene 2: rows Plate, Pin, Hole')
        c.check(tests.arc_edges(tests.inner(r)) > 0, 'scene 2: native circles in the Result')
        # Expected volumes (m3, polygons of the circles): the hole goes
        # through the pin (tube), the pin fills the hole above its base, or
        # the pin is disabled.
        area = ->(spec) { spec[:segments] / 2.0 * spec[:r]**2 * Math.sin(2 * Math::PI / spec[:segments]) }
        size = demo::PLATE
        top = demo::PIN[:z] + demo::PIN[:h]
        slab = size[:w] * size[:d] * size[:h]
        pin = area.call(demo::PIN) * (top - size[:h])
        tube = slab + pin - area.call(demo::HOLE) * top
        full = slab + pin - area.call(demo::HOLE) * demo::PIN[:z]
        no_pin = slab - area.call(demo::HOLE) * size[:h]
        m3 = 1.m.to_f**3
        near = ->(v, expected) { (v - expected * m3).abs < expected * m3 * 0.005 }
        volume = -> { Procedural.result_of(plate).volume }
        c.check(near.call(volume.call, tube), "scene 2: the hole goes through the pin (#{(volume.call / m3).round} m3)")
        c.later do
          tests.messages.clear
          Procedural.table_order(model, plate, %w[Plate Hole Pin].map { |n| demo.key_of(plate, n) })
          c.check(tests.messages.empty? && near.call(volume.call, full),
                  "table: pin after the hole, pin full at once (#{(volume.call / m3).round} m3)",
                  tests.messages.join(' / '))
          Procedural.table_order(model, plate, demo::PLATE_ORDER.map { |n| demo.key_of(plate, n) })
          c.check(near.call(volume.call, tube), 'table: order back, tube again')
        end
        c.later do
          tests.messages.clear
          Procedural.table_toggle(model, plate, demo.key_of(plate, 'Pin'), false)
          c.check(tests.messages.empty? && near.call(volume.call, no_pin), 'table: pin disabled, plate with its hole only',
                  tests.messages.join(' / '))
          Procedural.table_toggle(model, plate, demo.key_of(plate, 'Pin'), true)
          c.check(near.call(volume.call, tube), 'table: pin enabled again, tube again')
          tests.restore_auto_repair
        end
        # One image per scene, framed as the scenes of the demo, to check
        # the framing: results/demo-build-<major>-<n>.png.
        c.later do
          view = model.active_view
          camera = view.camera
          written = demo::SCENES.each_with_index.count do |(_name, part), k|
            demo.frame(view, [parts[part]].flatten)
            view.write_image(File.join(tests::RESULTS_DIR, "demo-build-#{Sketchup.version.to_i}-#{k}.png"))
          end
          view.camera = camera
          c.check(written == demo::SCENES.length, "#{written} scene image(s) written in results")
        end
      end

      # Q-8 (2.0.1): native booleans with a volume of several solids (one
      # group of four cylinders) leave one unused definition per solid; the
      # rebuild removes them, at Create and at Rebuild.
      test 'T19 Volume of several solids: no unused definition left' do |c, model|
        before = model.definitions.to_a
        unused = lambda do
          (model.definitions.to_a - before).select { |d| d.valid? && !d.group? && d.count_instances.zero? }
        end
        base = tests.box(model.entities, 0, 200, 0, 20, 20, 2, tests.base_material(model))
        centers = [[5, 5], [15, 5], [5, 15], [15, 15]].map { |a, b| tests.pt(a, 200 + b, -1) }
        holes = tests.cylinders(model.entities, centers, Z_AXIS, 1, 4)
        holes.material = tests.red(model)
        tests.select(model, base, holes)
        tests.messages.clear
        Procedural.do_create
        g = model.selection.find { |e| Procedural.procedural?(e) }
        c.check(g && tests.messages.empty?, 'Create: Solid Progress group with a volume of 4 holes',
                tests.messages.join(' / '))
        next c.phases.clear unless g
        c.check(unused.call.empty?, 'Create: no unused definition', unused.call.map(&:name).join(', '))
        c.later do
          tests.select(model, g)
          Procedural.do_rebuild
          r = Procedural.result_of(g)
          c.check(tests.messages.empty? && r && r.manifold?, 'Rebuild: Result solid', tests.messages.join(' / '))
          c.check(unused.call.empty?, 'Rebuild: no unused definition', unused.call.map(&:name).join(', '))
          model.selection.clear
        end
      end

      # A result that is not a solid is refused and the volume named, with
      # both engines. A native boolean on it would fail, and SketchUp then
      # cancels the whole open operation (a user model showed "reference to
      # deleted Group"). Two boxes that touch along an edge only give a
      # union that is not a solid; the subtract volume comes after it.
      test 'T20 Create: a union that is not a solid is named, nothing changed' do |c, model|
        a = tests.box(model.entities, 0, 260, 0, 10, 10, 10, tests.base_material(model))
        b = tests.box(model.entities, 10, 270, 0, 10, 10, 10)
        hole = tests.box(model.entities, 2, 262, -1, 2, 2, 12, tests.red(model))
        before = tests.procedural_groups(model).length
        tests.select(model, a, b, hole)
        tests.messages.clear
        Procedural.do_create
        message = tests.messages.join(' / ')
        c.check(tests.messages.length == 1 && message.include?('gives a result that is not a solid') &&
                message.include?('volume #2 ') && message.include?('Nothing was changed'),
                'message names the union that is not a solid (volume #2)', message)
        c.check(!message.include?('deleted'), 'no "reference to deleted" error', message)
        # The boxes touch along the vertical edge at x = 10, y = 270.
        at = "at x = #{Sketchup.format_length(10)}, y = #{Sketchup.format_length(270)}, between"
        c.check(message.include?('edge(s) at fault') && message.include?(at) && message.include?('Ruby Console'),
                'message gives where the result is not a solid (the common edge)', message)
        # The volumes there: the two boxes, not the hole (not combined yet).
        c.check(message =~ /\), volumes #1 [^,]+, #2 [^,.]+\./ && !message.include?('#3 '),
                'message names the volumes at the common edge (#1 and #2)', message)
        c.check(model.selection.length == 2 && model.selection.include?(a) && model.selection.include?(b),
                'only the volumes at fault stay selected', model.selection.map { |e| Procedural.label(e) }.join(', '))
        tool = model.tools.active_tool_name
        c.check(tool == 'RubyTool', 'edges at fault shown (FaultView tool active)', tool)
        model.select_tool(nil)
        # Edges on several planes (3 at z = 0, 2 at z = 50, 1 sloped): one
        # line per plane, not one box over them all.
        pt = ->(x, y, z) { Geom::Point3d.new(x, y, z) }
        fl = ->(v) { Sketchup.format_length(v) }
        edges = [[pt[0, 0, 0], pt[10, 0, 0], 1], [pt[10, 0, 0], pt[10, 10, 0], 1], [pt[10, 10, 0], pt[0, 10, 0], 1],
                 [pt[0, 0, 50], pt[10, 0, 50], 3], [pt[10, 0, 50], pt[10, 10, 50], 3], [pt[0, 0, 0], pt[5, 5, 50], 1]]
        place = Procedural.place_text(edges)
        c.check(place.start_with?(", by plane:\n- 3 at z = #{fl[0]}, between") &&
                place.include?("\n- 2 at z = #{fl[50]}, between") && place.include?("\n- 1 other(s), between"),
                'edges on several planes: one line per plane', place)
        place = Procedural.place_text(edges.first(3))
        c.check(place.start_with?(", at z = #{fl[0]}, between"), 'edges on one plane: one place', place)
        # FaultView draws every edge, in magenta, in screen coordinates.
        view = Object.new
        drawn = []
        view.define_singleton_method(:screen_coords) { |p| p }
        view.define_singleton_method(:line_width=) { |_w| }
        view.define_singleton_method(:drawing_color=) { |color| drawn << color }
        view.define_singleton_method(:draw2d) { |_mode, points| drawn << points.length }
        FaultView.new(edges).draw(view)
        c.check(drawn == ['magenta', 12], 'FaultView draws the 6 edges in magenta', drawn.inspect)
        c.check(tests.procedural_groups(model).length == before &&
                [a, b, hole].all? { |v| v.valid? && v.parent == model }, 'nothing created, volumes left as they were')
        model.start_operation('Solid Procedural tests — clean up', true)
        model.entities.erase_entities([a, b, hole].select(&:valid?))
        model.commit_operation
      end

      # Same union at the rebuild on exit, a transparent operation appended
      # to the edit: SketchUp would cancel the edit of the user with it.
      test 'T21 Rebuild on exit: a union that is not a solid keeps the edit' do |c, model|
        next c.skip('needs Model#active_path= (SketchUp 2020+)') unless tests.path_settable?(model)
        a = tests.box(model.entities, 30, 260, 0, 10, 10, 10, tests.base_material(model))
        b = tests.box(model.entities, 35, 265, 0, 10, 10, 10)
        hole = tests.box(model.entities, 32, 262, -1, 2, 2, 12, tests.red(model))
        tests.select(model, a, b, hole)
        tests.messages.clear
        Procedural.do_create
        g = model.selection.find { |e| Procedural.procedural?(e) }
        c.check(g && tests.messages.empty?, 'Create: Solid Progress group', tests.messages.join(' / '))
        next c.phases.clear unless g
        volume = Procedural.result_of(g).volume
        # The volume without material: it touches the base along an edge
        # once moved. Its position is read closed, as at the end: in an open
        # group, SketchUp gives model coordinates.
        moved = Procedural.sources_of(g).find { |s| s.material.nil? }
        x = moved.transformation.origin.x
        model.active_path = [g]
        c.later do
          model.start_operation('Solid Procedural tests — move a volume', true)
          moved.transform!(Geom::Transformation.translation(Geom::Vector3d.new(5, 5, 0)))
          model.commit_operation
          tests.messages.clear
          tests.close_all(model)
        end
        c.later do
          message = tests.messages.join(' / ')
          c.check(message.include?('Rebuild failed') && message.include?('gives a result that is not a solid'),
                  'message names the union that is not a solid', message)
          c.check(moved.valid? && (moved.transformation.origin.x - x - 5).abs < 1e-6, 'the edit of the user is kept')
          result = Procedural.result_of(g)
          c.check(result && !result.hidden? && (result.volume - volume).abs < 0.001, 'former Result kept and shown')
          c.check(Procedural.stale?(g), 'out of date: rebuilt at the next exit')
          model.start_operation('Solid Procedural tests — clean up', true)
          g.erase!
          model.commit_operation
        end
      end

      # Volumes in contact (faces, edges, circles), each with a red hole
      # through the base, so that their union is not the last step: either
      # a solid Result, or refused with the volume named and nothing
      # changed. The outcome of each specimen is noted.
      test 'T22 Specimens of volumes in contact (faces, edges, circles)' do |c, model|
        tests::CONTACT_SPECIMENS.each_with_index do |kind, k|
          x = 60 * k
          base, other = tests.contact_specimen(kind, model.entities, x, 320)
          hole = tests.box(model.entities, x + 4, 324, -1, 2, 2, 6, tests.red(model))
          volumes = [base, other, hole]
          next unless c.check(volumes.all?(&:manifold?), "#{kind}: specimen volumes are solids")
          before = tests.procedural_groups(model).length
          tests.select(model, volumes)
          tests.messages.clear
          Procedural.do_create
          message = tests.messages.join(' / ')
          g = model.selection.find { |e| Procedural.procedural?(e) }
          result = g && Procedural.result_of(g)
          outcome = if g && message.empty?
                      result && result.manifold? ? 'Result solid' : 'Result NOT a solid'
                    elsif message.include?('gives a result that is not a solid')
                      'refused: union not a solid'
                    elsif message =~ /of volume #\d+ .* failed\./
                      'refused: boolean failed'
                    else
                      "unexpected: #{message}"
                    end
          c.note("#{kind}: #{outcome}")
          unchanged = !g && tests.procedural_groups(model).length == before &&
                      volumes.all? { |v| v.valid? && v.parent == model }
          c.check(outcome == 'Result solid' || (outcome.start_with?('refused') && unchanged),
                  "#{kind}: solid Result, or refused with the volume named and nothing changed", message)
          model.start_operation('Solid Procedural tests — clean up', true)
          model.entities.erase_entities(g ? [g] : volumes.select(&:valid?))
          model.commit_operation
        end
      end

      test 'T11 No unused definition left' do |c, model|
        left = tests.unused_new_definitions(model)
        c.check(left.empty?, 'no unused component definition after all the tests',
                left.map { |d| "#{d.name} (#{d.entities.length} entities)" }.join(', '))
      end

      # Last test: the model of the tests is replaced. SketchUp 2017 keeps
      # the same Model object for the opened file but drops its observers.
      test 'T14 Save, File > New, File > Open: still procedural' do |c, model|
        Dir.mkdir(tests::RESULTS_DIR) unless File.directory?(tests::RESULTS_DIR)
        path = File.join(tests::RESULTS_DIR, "t14-#{Sketchup.version.to_i}.skp")
        File.delete(path) if File.exist?(path)
        base = tests.box(model.entities, 0, 160, 0, 10, 10, 10, tests.base_material(model))
        hole = tests.cylinder(model.entities, 5, 165, -2, 2, 14, tests.red(model))
        tests.select(model, base, hole)
        tests.messages.clear
        Procedural.do_create
        c.check(tests.procedural_groups(model).length >= 1 && tests.messages.empty?, 'procedural solid created',
                tests.messages.join(' / '))
        model.selection.clear
        c.later do
          c.check(model.save(path), 'model saved')
        end
        c.later do
          # A modified model would ask to be saved: a modal dialog.
          if c.check(!model.modified?, 'model unchanged after the save')
            Sketchup.file_new
          else
            c.phases.clear
          end
        end
        c.later do
          if c.check(!Sketchup.active_model.modified?, 'new model unchanged')
            c.check(Sketchup.open_file(path), 'file opened')
          else
            c.phases.clear
          end
        end
        c.later do
          m = Sketchup.active_model
          c.note("same Model object after File > Open: #{m.equal?(model)}")
          g = tests.procedural_groups(m).first
          c.check(g, 'opened file: procedural solid found')
          next c.phases.clear unless g
          c.check(Procedural.result_of(g) && !Procedural.result_of(g).hidden? &&
                  Procedural.sources_of(g).all?(&:hidden?), 'opened file: Result shown, sources hidden')
          tests.select(m, g)
        end
        c.later do
          m = Sketchup.active_model
          c.check(tests.green?(m), 'opened file: procedural solid selected, green frame (selection observer)')
          m.selection.clear
        end
        c.later do
          m = Sketchup.active_model
          c.check(!tests.green?(m), 'opened file: nothing selected, frame not green')
          g = tests.procedural_groups(m).first
          m.active_path = [g] if g && tests.path_settable?(m)
        end
        c.later do
          m = Sketchup.active_model
          g = tests.procedural_groups(m).first
          next c.note('display on entering not tested: no Model#active_path=') unless tests.path_settable?(m)
          c.check(g && Procedural.sources_of(g).none?(&:hidden?), 'opened file: entering shows the sources (model observer)')
          tests.close_all(m)
        end
        c.later do
          m = Sketchup.active_model
          g = tests.procedural_groups(m).first
          next unless tests.path_settable?(m)
          c.check(g && !Procedural.result_of(g).hidden?, 'opened file: exiting shows the Result')
        end
      end

      # After T14: the published demo model docs/demo.skp (made by hand, in
      # the SketchUp 2017 format: opened by every version) opens in this
      # SketchUp with its Solid Progress groups up to date. The model of the
      # tests is saved first, so File > Open asks nothing.
      test 'T18 Demo file opens (docs)' do |c, model|
        name = 'demo.skp'
        demo_path = File.join(tests::PROJECT_DIR, 'docs', name)
        next c.skip("docs/#{name} not there") unless File.exist?(demo_path)
        digest = tests.digest(demo_path)
        path = File.join(tests::RESULTS_DIR, "t18-#{Sketchup.version.to_i}.skp")
        File.delete(path) if File.exist?(path)
        c.check(model.save(path), 'model of the tests saved')
        c.later do
          if c.check(!Sketchup.active_model.modified?, 'model unchanged after the save')
            c.check(Sketchup.open_file(demo_path), "docs/#{name} opened")
          else
            c.phases.clear
          end
        end
        c.later do
          m = Sketchup.active_model
          groups = tests.procedural_groups(m)
          c.check(!groups.empty?, "#{groups.length} Solid Progress group(s) in the demo")
          groups.each do |g|
            r = Procedural.result_of(g)
            c.check(r && r.manifold? && !r.hidden? && !Procedural.stale?(g) && Procedural.sources_of(g).all?(&:hidden?),
                    "#{Procedural.group_label(g)}: up to date, Result solid and shown, sources hidden")
          end
          # The view of the file (or of each scene), to look at it:
          # results/demo-<major>-<n>.png.
          view = m.active_view
          cameras = m.pages.size.zero? ? [view.camera] : m.pages.map(&:camera)
          written = cameras.each_with_index.count do |cam, k|
            view.camera = cam
            view.write_image(File.join(tests::RESULTS_DIR, "demo-#{Sketchup.version.to_i}-#{k}.png"))
          end
          c.check(written == cameras.length, "#{written} image(s) of the demo written in results")
        end
        c.later do
          c.check(tests.digest(demo_path) == digest, "docs/#{name} unchanged by the test")
          # The demo file is not left open: closing SketchUp by hand would
          # offer to save it.
          if Sketchup.active_model.modified?
            c.note("docs/#{name} modified on opening: still open, do not save it")
          else
            Sketchup.file_new
          end
        end
      end
    end

    # -------------------------------------------------------------------
    # Report
    # -------------------------------------------------------------------

    def self.finish
      unhook
      lines = report_lines
      puts lines
      Dir.mkdir(RESULTS_DIR) unless File.directory?(RESULTS_DIR)
      major = Sketchup.version.to_i
      File.open(File.join(RESULTS_DIR, "latest-#{major}.txt"), 'w:UTF-8') { |f| f.puts lines }
      File.open(File.join(RESULTS_DIR, "history-#{major}.log"), 'a:UTF-8') { |f| f.puts lines; f.puts }
      Sketchup.status_text = "#{LOG} #{lines.last}"
    rescue => e
      puts "#{LOG} report error: #{e.message}"
    end

    def self.report_lines
      edition = Sketchup.is_pro? ? 'Pro' : 'Make'
      lines = ["Solid Procedural tests — SketchUp #{Sketchup.version} #{edition} — Ruby #{RUBY_VERSION} — " \
               "plugin #{SolidProcedural::VERSION} — #{@started.strftime('%Y-%m-%d %H:%M:%S')}"]
      passed = failed = skipped = checks = bad = 0
      (@cases || []).each do |c|
        checks += c.checks.length
        bad += c.checks.count { |k| !k[0] }
        if c.skipped
          skipped += 1
          lines << "SKIP  #{c.name} — #{c.skipped}"
        elsif c.failed?
          failed += 1
          lines << "FAIL  #{c.name}"
        else
          passed += 1
          lines << "PASS  #{c.name} (#{c.checks.length} checks)"
        end
        c.checks.each do |ok, label, detail|
          next if ok && !c.failed?
          text = "      #{ok ? 'ok' : 'XX'} #{label}"
          text += " — #{detail}" if !ok && detail && !detail.to_s.empty?
          lines << text
        end
        c.notes.each { |n| lines << "      · #{n}" }
      end
      lines << "FATAL #{@fatal}" if @fatal
      lines << format('DONE  passed=%d failed=%d skipped=%d checks=%d failed_checks=%d time=%.1fs',
                      passed, failed + (@fatal ? 1 : 0), skipped, checks, bad, Time.now - @started)
      lines
    end

    # -------------------------------------------------------------------
    # Make 2017, by hand: onActivePathChanged
    # -------------------------------------------------------------------

    # A box with a hole. Once the user has opened it, the hole is moved
    # half out of the box (as an edit would); once closed, the Result must
    # be shown and rebuilt (larger volume), with the engine of this SketchUp.
    def self.manual_open_test
      model = Sketchup.active_model
      model.start_operation('Solid Procedural tests — open me', true)
      base = box(model.entities, 0, -40, 0, 10, 10, 10, base_material(model))
      hole = cylinder(model.entities, 5, -35, -2, 2, 14, red(model))
      model.commit_operation
      select(model, base, hole)
      Procedural.do_create
      g = procedural_groups(model).last
      return puts("#{LOG} manual test: no procedural solid created") unless g
      g.name = 'SP Test - open me'
      @manual = { group: g, opened: false, deadline: Time.now + 120, volume: Procedural.result_of(g).volume }
      Sketchup.status_text = "#{LOG} Double-click 'SP Test - open me', then exit it (2 minutes)"
      puts "#{LOG} Double-click 'SP Test - open me', then exit it (2 minutes)"
      watch_manual
    end

    def self.watch_manual
      m = @manual
      g = m[:group]
      timer = UI.start_timer(0.5, false) do
        UI.stop_timer(timer)
        model = Sketchup.active_model
        path = model.active_path || []
        if !m[:opened] && path.include?(g)
          m[:opened] = true
          m[:shown] = Procedural.sources_of(g).none?(&:hidden?)
          hole = Procedural.sources_of(g).last
          model.start_operation('Solid Procedural tests — move the hole', true)
          hole.transform!(Geom::Transformation.translation(Geom::Vector3d.new(5, 0, 0)))
          model.commit_operation
          Sketchup.status_text = "#{LOG} The hole was moved: now exit 'SP Test - open me'"
        end
        if m[:opened] && !path.include?(g)
          result = Procedural.result_of(g)
          shown = result && !result.hidden? ? true : false
          rebuilt = result && result.volume > m[:volume] + 1 && !Procedural.stale?(g) ? true : false
          engine = Procedural.ruby_engine? ? 'Ruby engine' : 'native'
          text = "manual test (#{engine}): opened -> sources shown=#{m[:shown]}; " \
                 "closed -> Result shown=#{shown}, rebuilt=#{rebuilt} " \
                 "(volume #{m[:volume].round(2)} -> #{result ? result.volume.round(2) : 'none'})"
          puts "#{LOG} #{text}"
          File.open(File.join(RESULTS_DIR, "manual-#{Sketchup.version.to_i}.txt"), 'w:UTF-8') { |f| f.puts text }
          Sketchup.status_text = "#{LOG} #{text}"
        elsif Time.now > m[:deadline]
          puts "#{LOG} manual test: timed out"
          File.open(File.join(RESULTS_DIR, "manual-#{Sketchup.version.to_i}.txt"), 'w:UTF-8') do |f|
            f.puts "manual test: timed out (opened=#{m[:opened]})"
          end
        else
          watch_manual
        end
      end
    end
  end
end

$VERBOSE = verbose

# Started once SketchUp is idle (also when loaded by -RubyStartup).
unless $sp_tests_no_autorun
  sp_tests_timer = UI.start_timer(1, false) do
    UI.stop_timer(sp_tests_timer)
    SolidProcedural::Tests.run
  end
end
