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
      circle_restore solid_operations procedural procedural_table highlight main
    ].freeze

    def self.plugin_dir
      File.join(SolidProcedural::PLUGIN_DIR, 'solid_procedural')
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
      sp = SolidProcedural.singleton_class
      # Plugin methods: aliased again after each reload of the plugin.
      sp.send(:alias_method, :sp_tests_pro_only?, :pro_only?)
      Procedural.singleton_class.send(:alias_method, :sp_tests_ruby_engine?, :ruby_engine?)
      @hooked = true
    end

    def self.unhook
      return unless @hooked
      UI.singleton_class.send(:alias_method, :messagebox, :sp_tests_messagebox)
      Sketchup.singleton_class.send(:alias_method, :status_text=, :sp_tests_status_text=)
      SolidProcedural.singleton_class.send(:alias_method, :pro_only?, :sp_tests_pro_only?)
      restore_engine
      @hooked = false
    end

    def self.force_pro_only(value)
      SolidProcedural.define_singleton_method(:pro_only?) { value }
    end

    def self.force_engine(ruby)
      Procedural.define_singleton_method(:ruby_engine?) { ruby }
    end

    def self.restore_engine
      Procedural.singleton_class.send(:alias_method, :ruby_engine?, :sp_tests_ruby_engine?)
    end

    def self.restore_pro_only
      SolidProcedural.singleton_class.send(:alias_method, :pro_only?, :sp_tests_pro_only?)
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

    # -------------------------------------------------------------------
    # Tests
    # -------------------------------------------------------------------

    def self.define_tests
      tests = self

      test 'T01 Plugin loaded, installed copy = project' do |c, _model|
        c.check(defined?(SolidProcedural::VERSION), 'VERSION defined')
        c.note("plugin #{SolidProcedural::VERSION}, SketchUp #{Sketchup.version}, " \
               "Pro=#{Sketchup.is_pro?}, Ruby #{RUBY_VERSION}, union defined=#{Sketchup::Group.method_defined?(:union)}")
        c.check(defined?(SolidProcedural::PRO_ONLY) && [true, false].include?(SolidProcedural::PRO_ONLY),
                'PRO_ONLY switch defined (true / false)')
        c.note("PRO_ONLY = #{SolidProcedural::PRO_ONLY}")
        c.check(Procedural.respond_to?(:remove_definition), 'Procedural.remove_definition defined')
        c.check(ProceduralTable.respond_to?(:active_path_settable?), 'ProceduralTable.active_path_settable? defined')
        project = File.join(tests::PROJECT_DIR, 'solid_procedural')
        files = Dir.glob(File.join(project, '**', '*')).select { |f| File.file?(f) }
        different = files.reject do |f|
          tests.digest(f) == tests.digest(File.join(tests.plugin_dir, f[(project.length + 1)..-1]))
        end
        c.check(!files.empty? && different.empty?, "installed plugin identical to the project (#{files.length} files)",
                different.map { |f| f[(project.length + 1)..-1] }.join(', '))
        html = File.read(File.join(tests.plugin_dir, 'html', 'procedural_table.html'))
        c.check(html.include?('-webkit-user-select'), 'table page has -webkit-user-select')
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

      test 'T10 PRO_ONLY switch' do |c, model|
        tests.force_pro_only(true)
        begin
          base = tests.box(model.entities, 0, 90, 0, 10, 10, 10)
          tests.select(model, base)
          before = tests.procedural_groups(model).length
          tests.messages.clear
          Procedural.do_create
          after = tests.procedural_groups(model).length
          if tests.pro?
            c.check(after == before + 1 && tests.messages.empty?, 'Pro: Create works as usual')
          else
            c.check(tests.messages.any? { |m| m.include?('requires SketchUp Pro') }, 'Make: "requires SketchUp Pro"',
                    tests.messages.join(' / '))
            c.check(after == before && base.parent == model, 'Make: nothing created')
            g = @state[:single]
            if g && g.valid?
              tests.select(model, g)
              tests.messages.clear
              Procedural.do_rebuild
              c.check(tests.messages.any? { |m| m.include?('requires SketchUp Pro') }, 'Make: Rebuild refused')
            end
          end
        ensure
          tests.restore_pro_only
        end
        c.check(SolidProcedural.pro_only? == SolidProcedural::PRO_ONLY, 'switch restored')
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
        end]
      ]
      engines = tests.pro? ? [false, true] : [true]
      engines.each_with_index do |ruby, e|
        cases.each_with_index do |(name, expected, second_op, build), i|
          label = ruby ? 'Ruby engine' : 'native'
          test "T12 #{label}: #{name}" do |c, model|
            tests.force_engine(ruby)
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
              others = g.entities.to_a - Procedural.sources_of(g) - [result]
              c.check(others.empty?, 'nothing else left in the group', others.map { |x| x.class.name }.join(', '))
            ensure
              tests.restore_engine
            end
          end
        end
      end

      test 'T11 No unused definition left' do |c, model|
        left = tests.unused_new_definitions(model)
        c.check(left.empty?, 'no unused component definition after all the tests',
                left.map { |d| "#{d.name} (#{d.entities.length} entities)" }.join(', '))
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
