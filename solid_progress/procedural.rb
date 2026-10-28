# encoding: UTF-8
require 'digest/md5'

module SolidProcedural
  # Procedural — non-destructive procedural solids.
  #
  # A procedural solid is a group (attribute role=procedural) that holds its
  # source volumes (role=source) and their combination (role=result):
  #   - open for editing: sources shown, Result hidden;
  #   - closed: sources hidden, Result shown, rebuilt when the group is
  #     closed after a change of its sources.
  #
  # Attributes (dictionary DICT) of each source:
  #   rank         position in the operation list (1 = base)
  #   op           'union', 'outer_shell' or 'subtract'
  #   last_add_op  'union' or 'outer_shell', restored when a subtract volume
  #                is repainted with another color
  #   enabled      false = ignored by the rebuild
  #   seen_color   material key at the last rebuild: the color sets the
  #                operation only when the material changed, so changing the
  #                subtract color never flips existing volumes
  #   prev_material  material name ('none' = default) restored when the
  #                volume left Subtract in the Procedural Table (before 2.2.0)
  #   orig_material  material name taken off the volume to show it neutral,
  #                given back when the volume leaves the group
  #   uid          key of the volume in the Procedural Table, kept by copies
  # Two colors only for the plain volumes inside a group: the subtract
  # color for a subtracted volume, the default material for an added one
  # (neutralize). The group stores its color (attribute color: a material
  # name, 'none' = default), shown by its Result, kept on its faces in the
  # Result of a group that holds it (bake_color) and by Finalize, and
  # the signature (MD5) of its sources at the last rebuild:
  # a rebuild runs only when it differs, and Ctrl+Z restores it together
  # with the former Result.
  #
  # Rebuild: copies of the enabled sources (made unique, a copy shares its
  # definition) combined in rank order with the native Pro booleans. The
  # former Result is replaced only on success and every copy is erased on
  # failure, so a rebuild never needs abort_operation (which must not be
  # used on a transparent operation).
  module Procedural
    DICT = 'SolidProcedural'.freeze
    ROLE_PROCEDURAL = 'procedural'.freeze
    ROLE_SOURCE = 'source'.freeze
    ROLE_RESULT = 'result'.freeze
    OP_LABELS = { 'union' => 'Union', 'outer_shell' => 'Shell', 'subtract' => 'Subtract' }.freeze
    DEFAULT_NAME = 'Solid Progress'.freeze
    RESULT_NAME = 'Result'.freeze
    SUBTRACT_MATERIAL_NAME = 'Solid Progress Subtract'.freeze
    LOG = '[Solid Progress]'.freeze

    # true (option B): the automatic rebuild on exit is appended to the last
    # edit (transparent operation), so one Ctrl+Z undoes the edit and its
    # result. false (option A): separate undo step.
    MERGE_REBUILD_WITH_LAST_EDIT = true

    # Message for the user; the rebuild that raised it changed no geometry
    # and kept the former Result.
    class RebuildError < StandardError; end

    # Raised by the Pro only line (see ruby_engine?): the message names that
    # line, the one to comment out again.
    class ProOnly < RebuildError
      def initialize(line)
        super("PRO Only vs. #{File.basename(__FILE__)}:#{line}")
      end
    end

    # A result that is not a solid: +edges+ are its edges at fault (see
    # faulty_edges), shown in magenta after the message.
    class NotSolidError < RebuildError
      attr_reader :edges

      def initialize(message, edges)
        super(message)
        @edges = edges
      end
    end

    # Procedural groups of the active path already synchronized, per model
    # (kept when the file is reloaded).
    @synced_paths ||= {}

    # -------------------------------------------------------------------
    # Queries
    # -------------------------------------------------------------------

    def self.role(entity)
      entity.get_attribute(DICT, 'role')
    end

    def self.instance?(entity)
      entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
    end

    def self.procedural?(entity)
      entity.is_a?(Sketchup::Group) && entity.valid? && role(entity) == ROLE_PROCEDURAL
    end

    def self.result_of(group)
      group.entities.find { |e| instance?(e) && role(e) == ROLE_RESULT }
    end

    # Source volumes in rank order; volumes without a rank yet (added in the
    # group) come last, in entity order.
    def self.sources_of(group)
      all = group.entities.select { |e| instance?(e) && role(e) != ROLE_RESULT }
      ranked, fresh = all.partition { |s| s.get_attribute(DICT, 'rank') }
      ranked.sort_by { |s| s.get_attribute(DICT, 'rank').to_i } + fresh
    end

    def self.op_of(source)
      source.get_attribute(DICT, 'op') ||
        (SolidProcedural.is_subtract_solid?(source) ? 'subtract' : 'union')
    end

    def self.enabled?(source)
      source.get_attribute(DICT, 'enabled') != false
    end

    # Attributes of a volume in its Solid Progress group. A nested Solid
    # Progress group keeps its own attributes (role, signature) next to them.
    SOURCE_KEYS = %w[rank op uid enabled seen_color last_add_op prev_material orig_material].freeze

    def self.clear_source_keys(entity)
      SOURCE_KEYS.each { |k| entity.delete_attribute(DICT, k) }
    end

    # A solid volume; a nested Solid Progress group through its Result.
    def self.solid_volume?(volume)
      return volume.manifold? unless procedural?(volume)
      result = result_of(volume)
      !result.nil? && result.manifold?
    end

    def self.label(source)
      name = source.name.to_s
      name = source.definition.name if name.empty?
      rank = source.get_attribute(DICT, 'rank')
      rank ? "##{rank} #{name}" : name
    end

    def self.group_label(group)
      group.name.to_s.empty? ? DEFAULT_NAME : group.name
    end

    def self.material_key(material)
      return 'none' unless material
      c = material.color
      "#{material.name}:#{c.red},#{c.green},#{c.blue}"
    end

    def self.subtract_material?(material)
      return false unless material
      SolidProcedural.color_match?(material.color, SolidProcedural.subtract_color)
    end

    # Procedural groups of the active path, outermost first.
    def self.open_groups(model)
      (model.active_path || []).select { |e| procedural?(e) }
    end

    def self.all_groups(model)
      model.definitions.select(&:group?).flat_map(&:instances).select { |g| procedural?(g) }
    end

    # -------------------------------------------------------------------
    # Signature: what the Result depends on
    # -------------------------------------------------------------------

    def self.signature(group)
      md5 = Digest::MD5.new
      digests = {}
      sources_of(group).each do |s|
        md5 << [s.get_attribute(DICT, 'rank'), op_of(s), enabled?(s), material_key(s.material)].inspect
        md5 << rounded(s.transformation.to_a).inspect
        md5 << (digests[s.definition] ||= geometry_digest(s.definition.entities))
      end
      md5.hexdigest
    end

    def self.geometry_digest(entities)
      md5 = Digest::MD5.new
      entities.each do |e|
        case e
        when Sketchup::Edge
          md5 << rounded(e.start.position.to_a + e.end.position.to_a).inspect
        when Sketchup::Face
          md5 << "f#{e.vertices.length}"
        when Sketchup::Group, Sketchup::ComponentInstance
          md5 << rounded(e.transformation.to_a).inspect
          # The color of a nested Result stays on its faces in the Result
          # of the groups that hold it: a new color rebuilds them.
          md5 << material_key(e.material)
          md5 << geometry_digest(e.definition.entities)
        end
      end
      md5.hexdigest
    end

    def self.rounded(values)
      values.map { |v| v.to_f.round(6) }
    end

    def self.stale?(group)
      group.get_attribute(DICT, 'signature') != signature(group)
    end

    # -------------------------------------------------------------------
    # Display: sources inside, Result outside
    # -------------------------------------------------------------------

    # Entities whose visibility follows the edit state (guides, texts and
    # dimensions are left alone).
    def self.display_entities(group)
      group.entities.select do |e|
        instance?(e) || e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Face)
      end
    end

    def self.hidden_wanted?(entity, inside)
      (role(entity) == ROLE_RESULT) == inside
    end

    def self.display_changes(group, inside)
      display_entities(group).reject { |e| e.hidden? == hidden_wanted?(e, inside) }
    end

    def self.apply_display(group, inside)
      changes = display_changes(group, inside)
      return if changes.empty?
      # A copied group shares its definition: the copy must not change too.
      group.make_unique
      display_changes(group, inside).each { |e| e.hidden = hidden_wanted?(e, inside) }
    end

    def self.loose_geometry?(group)
      group.entities.any? { |e| e.is_a?(Sketchup::Face) }
    end

    # -------------------------------------------------------------------
    # Rebuild
    # -------------------------------------------------------------------

    # Ranks 1..n, role, uid, enabled by default, operation from the color
    # when the material changed since the last rebuild. Writes only what
    # differs.
    def self.normalize_sources(group)
      sources = sources_of(group)
      # Its color, before the volumes turn neutral: groups made before 2.2.0
      # take it from the painted group, else from the base.
      unless group.get_attribute(DICT, 'color')
        color = initial_color(group)
        group.set_attribute(DICT, 'color', color ? color.name : 'none')
      end
      used = {}
      sources.each_with_index do |s, i|
        set_attribute(s, 'role', ROLE_SOURCE) if role(s).nil?
        uid = s.get_attribute(DICT, 'uid')
        # A source copied inside the group has the uid of its original.
        if uid.nil? || used[uid]
          uid = new_uid(used)
          s.set_attribute(DICT, 'uid', uid)
        end
        used[uid] = true
        set_attribute(s, 'rank', i + 1)
        # The base (first row) is always enabled.
        set_attribute(s, 'enabled', true) if i.zero? || s.get_attribute(DICT, 'enabled').nil?
        sync_op_with_color(s)
        neutralize(group.model, s)
        # A nested group shows the color of its row: neutral or subtract.
        apply_result_color(s) if procedural?(s)
      end
      sources
    end

    # Two colors in a Solid Progress group: the subtract color for a
    # subtracted volume, the default material for an added one. A material
    # taken off is kept in orig_material, given back when the volume leaves
    # the group (release_orphans).
    def self.neutralize(model, source)
      if op_of(source) == 'subtract'
        source.material = subtract_material(model) unless subtract_material?(source.material)
      elsif source.material
        if procedural?(source)
          # A nested group painted by hand keeps the color of its table (a
          # group made before 2.2.0 takes the paint as its color).
          source.set_attribute(DICT, 'color', source.material.name) unless source.get_attribute(DICT, 'color')
        else
          set_attribute(source, 'orig_material', source.material.name)
        end
        source.material = nil
      end
      set_attribute(source, 'seen_color', material_key(source.material))
    end

    def self.set_attribute(entity, key, value)
      entity.set_attribute(DICT, key, value) if entity.get_attribute(DICT, key) != value
    end

    def self.new_uid(used)
      loop do
        uid = format('%08x', rand(0x100000000))
        return uid unless used[uid]
      end
    end

    def self.sync_op_with_color(source)
      key = material_key(source.material)
      op = source.get_attribute(DICT, 'op')
      seen = source.get_attribute(DICT, 'seen_color')
      return if op && seen == key
      if subtract_material?(source.material)
        if op && op != 'subtract'
          set_attribute(source, 'last_add_op', op)
          # Material before the repaint, restored if the table sets it back.
          set_attribute(source, 'prev_material', seen.nil? || seen == 'none' ? 'none' : seen.rpartition(':').first)
        end
        op = 'subtract'
      elsif op.nil? || op == 'subtract'
        op = source.get_attribute(DICT, 'last_add_op') || 'union'
      end
      set_attribute(source, 'op', op)
      set_attribute(source, 'seen_color', key)
    end

    def self.validate(active)
      raise RebuildError, 'There is no enabled volume to combine.' if active.empty?
      active.each do |s|
        next if solid_volume?(s)
        if procedural?(s)
          raise RebuildError, "Volume #{label(s)} is a Solid Progress group whose Result is not a solid: " \
                              'rebuild it first.'
        end
        raise RebuildError, "Volume #{label(s)} is not a solid."
      end
      return unless op_of(active.first) == 'subtract'
      raise RebuildError, "The first volume #{label(active.first)} has the subtract color: " \
                          'the first volume must be added.'
    end

    # Rebuilds +group+ (closed, not in the active path) in the operation
    # opened by the caller. Returns [note, warning]: warning is a message
    # for the user (circle restoration skipped or failed) or nil.
    # Raises RebuildError.
    def self.rebuild_in_operation(model, group)
      # First, before any change: the Pro only line raises here.
      ruby = ruby_engine?
      selected = model.selection.to_a
      group.make_unique
      sources = normalize_sources(group)
      active = sources.select { |s| enabled?(s) }
      # Nested Solid Progress groups first, from the inside out: their
      # Result is the volume used here.
      active.each { |s| rebuild_in_operation(model, s) if procedural?(s) && stale?(s) }
      validate(active)
      sig = signature(group)
      puts "#{LOG} Rebuild '#{group_label(group)}': #{active.length} volume(s)" +
           (ruby ? ', SketchUp Make engine' : '')

      if loose_geometry?(group)
        puts "#{LOG}   Loose geometry ignored: make it a group to use it as a volume"
      end

      created = []
      definitions = model.definitions.to_a
      begin
        copies = []
        result = nil
        before = group.entities.to_a
        begin
          result = combine(model, group, active, copies, created)
        ensure
          copies.each { |c| c.erase! if c.valid? && c != result }
          # Whatever an engine left in the group (a temporary group after an
          # error would become a source): only the result stays. A failed
          # native boolean cancels the whole operation, the new group too.
          if group.valid?
            left = (group.entities.to_a - before).select { |e| e.valid? && e != result }
            group.entities.erase_entities(left) unless left.empty?
          end
        end

        result.material = result_material(group)
        # A single component volume gives a component instance, not a group.
        CircleRestore.inner_entities(result).grep(Sketchup::Face).each do |f|
          f.material = nil if subtract_material?(f.material)
          f.back_material = nil if subtract_material?(f.back_material)
        end
        result, note, warning = restore_circles(result, created)
      ensure
        # Native booleans with a volume of several solids leave one unused
        # definition per solid (TempInstance#n): removed too.
        created.concat((model.definitions.to_a - definitions).reject(&:group?))
        created.each do |d|
          remove_definition(model, d) if d.valid? && d.count_instances.zero?
        end
      end

      old = result_of(group)
      if old
        # The Result of a single component volume is a component instance:
        # its definition must not stay unused (a copy may still use it).
        unused = old.definition if old.is_a?(Sketchup::ComponentInstance)
        old.erase!
        remove_definition(model, unused) if unused && unused.valid? && unused.count_instances.zero?
      end
      result.set_attribute(DICT, 'role', ROLE_RESULT)
      result.name = RESULT_NAME
      group.set_attribute(DICT, 'signature', sig)
      apply_display(group, open_groups(model).include?(group))
      puts "#{LOG} Rebuild '#{group_label(group)}' done: #{note}"
      [note, warning]
    ensure
      # combine clears the selection: select again what still exists.
      kept = (selected || []).select(&:valid?)
      model.selection.add(kept) unless kept.empty?
    end

    # Combines copies of +active+ in order. Every copy and intermediate
    # result is listed in +copies+, component definitions made unique in
    # +created+, so that the caller can clean up.
    def self.combine(model, group, active, copies, created)
      ruby = ruby_engine?
      entities = group.entities
      acc = copy_of(active.first, entities, created)
      copies << acc
      total = active.length - 1
      active.drop(1).each_with_index do |source, i|
        op = op_of(source)
        # Before the boolean: the operation cancelled by a failed native
        # boolean takes the rank of the volume with it.
        name = label(source)
        pct = ((i + 1) * 100.0 / total).round
        Sketchup.status_text = "Solid Progress — #{OP_LABELS[op]} #{i + 1}/#{total} (#{pct}%)" +
                               (ruby ? ' — SketchUp Make engine' : '')
        copy = copy_of(source, entities, created)
        copies << copy
        model.selection.clear
        # Native subtract: tool.subtract(base) subtracts the tool from the
        # base, erases the tool and returns the modified base.
        res = if ruby
                ruby_boolean(op, acc, copy)
              else
                case op
                when 'union' then acc.union(copy)
                when 'outer_shell' then acc.outer_shell(copy)
                else copy.subtract(acc)
                end
              end
        unless res && res.valid?
          raise RebuildError, "#{OP_LABELS[op]} of volume #{name} failed."
        end
        copies << res
        # A result that is not a solid is refused, whatever the engine. With
        # the native booleans, the next boolean would fail and SketchUp then
        # cancels the whole open operation (a transparent one with the
        # previous edit of the user).
        unless res.manifold?
          edges = faulty_edges(res, group.transformation)
          # The message names, for each place, the volumes combined so far
          # that have a face there.
          cache = {}
          involved = lambda do |some|
            touching_volumes(active.first(i + 2), some, group.transformation, cache).map { |v| label(v) }
          end
          raise NotSolidError.new(not_solid_message("#{OP_LABELS[op]} of volume #{name}", edges, involved), edges)
        end
        acc = res
      end
      acc
    end

    # Edges at most listed in the Ruby Console for a result that is not a
    # solid.
    MAX_LISTED_EDGES = 50

    # Edges of +solid+ that do not border exactly two faces (where it is not
    # a solid), as [start, end, face count], in the coordinates of the
    # model: +transformation+ is the one of the context that holds +solid+
    # (an instance of the active context reports model coordinates).
    def self.faulty_edges(solid, transformation)
      t = transformation * solid.transformation
      CircleRestore.inner_entities(solid).grep(Sketchup::Edge).reject { |e| e.faces.length == 2 }.map do |e|
        [e.start.position.transform(t), e.end.position.transform(t), e.faces.length]
      end
    end

    # Message for a result that is not a solid: where its faulty +edges+
    # are, and what to check there. The edges are listed in the Ruby
    # Console. +involved+, if given, names the volumes at some edges.
    def self.not_solid_message(step, edges, involved = nil)
      puts "#{LOG} #{step}: #{edges.length} edge(s) where the result is not a solid (start - end, faces)"
      edges.first(MAX_LISTED_EDGES).each do |a, b, faces|
        puts "#{LOG}   #{point_text(a)} - #{point_text(b)}, #{faces} face(s)"
      end
      puts "#{LOG}   ... #{edges.length - MAX_LISTED_EDGES} more" if edges.length > MAX_LISTED_EDGES
      return "#{step} gives a result that is not a solid." if edges.empty?
      "#{step} gives a result that is not a solid: #{edges.length} edge(s) at fault" \
        "#{place_text(edges, involved)}.\nCheck the volumes there: faces in simple contact, edges that " \
        'coincide, tangent circles or arcs. Make them overlap (move or enlarge a volume slightly), then try ' \
        'again. The edges are shown in magenta until you press Escape, and listed in the Ruby Console.'
    end

    # Planes at most named in the message; the other edges are counted
    # together.
    MAX_LISTED_PLANES = 3

    # Where the +edges+ are: ", at z = …, between (…) and (…), volumes …"
    # when they are on one plane, else one line per plane, ", by
    # plane:\n- 31 at z = …, between (…) and (…), volumes …\n- 30 at z =
    # …\n- 6 other(s), …" (one box over all the edges would cover the whole
    # model).
    def self.place_text(edges, involved = nil)
      groups, rest = plane_groups(edges)
      parts = groups.map { |group| "#{group.length} #{box_text(group, involved)}" }
      parts << "#{rest.length} other(s), #{box_text(rest, involved)}" unless rest.empty?
      parts.length > 1 ? ", by plane:\n- #{parts.join("\n- ")}" : ", #{box_text(edges, involved)}"
    end

    # The +edges+ grouped by plane of the axes (x, y or z the same at both
    # ends), the plane with the most edges first: at most MAX_LISTED_PLANES
    # planes of two edges or more, and the other edges in +rest+.
    def self.plane_groups(edges)
      planes = ->(a, b) { (0..2).select { |k| (a[k] - b[k]).abs < 0.001 }.map { |k| [k, a[k].to_f.round(3)] } }
      groups = []
      rest = edges
      while groups.length < MAX_LISTED_PLANES && rest.length > 1
        counts = Hash.new(0)
        rest.each { |a, b, _faces| planes.call(a, b).each { |plane| counts[plane] += 1 } }
        plane, count = counts.max_by { |_plane, n| n }
        break unless count && count > 1
        group, rest = rest.partition { |a, b, _faces| planes.call(a, b).include?(plane) }
        groups << group
      end
      [groups, rest]
    end

    # "at z = …, between (…) and (…), volumes …": the box of the +edges+,
    # the coordinates they all share and the volumes named by +involved+.
    def self.box_text(edges, involved = nil)
      box = Geom::BoundingBox.new
      edges.each { |a, b, _faces| box.add(a, b) }
      shared = %w[x y z].each_with_index.select { |_axis, k| (box.max[k] - box.min[k]).abs < 0.001 }
      at = shared.map { |axis, k| "#{axis} = #{Sketchup.format_length(box.min[k])}" }
      names = involved ? involved.call(edges) : []
      (at.empty? ? '' : "at #{at.join(', ')}, ") + "between #{point_text(box.min)} and #{point_text(box.max)}" +
        (names.empty? ? '' : ", volumes #{names.join(', ')}")
    end

    # Points at most tested, for a group of edges, to find the volumes there:
    # every edge, a volume may touch only a few of them (a frame flush with
    # a cylinder: 4 straight edges out of 24).
    MAX_TESTED_POINTS = 200

    ON_FACE = [Sketchup::Face::PointInside, Sketchup::Face::PointOnVertex, Sketchup::Face::PointOnEdge].freeze

    # The +volumes+ (instances of the context of +transformation+) that
    # have a face through the middle of some of the +edges+ (model
    # coordinates). +cache+ keeps the faces of each volume between calls.
    def self.touching_volumes(volumes, edges, transformation, cache = {})
      step = [(edges.length + MAX_TESTED_POINTS - 1) / MAX_TESTED_POINTS, 1].max
      all = edges.each_slice(step).map(&:first).map { |a, b, _faces| Geom.linear_combination(0.5, a, 0.5, b) }
      inverse = transformation.inverse
      in_context = all.map { |p| p.transform(inverse) }
      volumes.select do |v|
        # Only the points in the box of the volume: the faces of a volume
        # far from the edges are not looked at.
        box = v.bounds
        points = all.select.with_index { |_p, k| near_box?(box, in_context[k]) }
        next false if points.empty?
        frames = cache[v] ||= face_frames(v, transformation * v.transformation)
        frames.any? do |inverse, faces|
          locals = points.map { |p| p.transform(inverse) }
          faces.any? do |face, nx, ny, nz, d|
            locals.any? do |q|
              (nx * q.x + ny * q.y + nz * q.z + d).abs < 0.001 && ON_FACE.include?(face.classify_point(q))
            end
          end
        end
      end
    end

    # Floats: two Lengths closer than the tolerance of SketchUp compare as
    # equal (a point on the box would be outside).
    def self.near_box?(box, point)
      (0..2).all? { |k| point[k].to_f > box.min[k].to_f - 0.001 && point[k].to_f < box.max[k].to_f + 0.001 }
    end

    # [[inverse transformation, [[face, nx, ny, nz, d], …]], …]: the faces of
    # +instance+ and of the instances it holds, with their planes; +t+ is
    # the transformation of +instance+ to model coordinates.
    def self.face_frames(instance, t, frames = [])
      entities = CircleRestore.inner_entities(instance)
      faces = entities.grep(Sketchup::Face).map do |f|
        n = f.normal
        p = f.vertices.first.position
        [f, n.x, n.y, n.z, -(n.x * p.x + n.y * p.y + n.z * p.z)]
      end
      frames << [t.inverse, faces] unless faces.empty?
      entities.each { |e| face_frames(e, t * e.transformation, frames) if instance?(e) }
      frames
    end

    def self.point_text(point)
      "(#{point.to_a.map { |v| Sketchup.format_length(v) }.join(', ')})"
    end

    # Boolean engine: the native booleans of SketchUp Pro, else the Ruby
    # engine (SolidOperations, from Solid for Maker) for SketchUp Make.
    # The only SketchUp edition check of the plugin. To keep the plugin for
    # SketchUp Pro only, uncomment the next line: without Pro, Create,
    # Rebuild, Finalize, the automatic rebuild and the Procedural Table then
    # show "PRO Only vs. procedural.rb:<line>" and change nothing.
    def self.ruby_engine?
      ruby = !Sketchup.is_pro?
      # raise ProOnly, __LINE__ if ruby
      ruby
    end

    # Ruby engine: the base +acc+ is modified in place and the tool +copy+
    # erased. Returns the base, or nil on failure.
    def self.ruby_boolean(op, acc, copy)
      status = case op
               when 'union' then SolidOperations.union(acc, copy)
               when 'outer_shell' then SolidOperations.outer_shell(acc, copy)
               else SolidOperations.subtract(acc, copy)
               end
      status ? acc : nil
    end

    # Visible copy of +source+ in +entities+, with its own definition (a
    # copy shares the definition of its source, which a boolean would then
    # modify too) and without the procedural attributes.
    def self.copy_of(source, entities, created)
      copy = duplicate(source, entities, created)
      if procedural?(source)
        copy = result_copy(copy, created)
        if source.material
          # Painted with the subtract color: a tool, like any red volume.
          copy.material = source.material
        else
          # Its color stays on its faces in the Result of this group.
          bake_color(copy)
        end
      else
        copy.material = source.material
      end
      copy.hidden = false
      copy.delete_attribute(DICT)
      copy
    end

    # The Result of +copy+, a copy of a nested Solid Progress group, alone in
    # the context of the copy: its sources are erased, the copy exploded.
    # Made unique, so that a boolean never changes the nested Result.
    def self.result_copy(copy, created)
      result = result_of(copy)
      raise RebuildError, "Volume #{label(copy)} has no Result: rebuild it first." unless result
      copy.entities.erase_entities(copy.entities.to_a - [result])
      solid = copy.explode.find { |e| instance?(e) && e.valid? }
      raise RebuildError, "The Result of volume #{label(copy)} could not be used." unless solid
      solid.make_unique
      created << solid.definition if solid.is_a?(Sketchup::ComponentInstance)
      solid
    end

    # The material of +instance+ on its faces of the default material, so
    # that the booleans keep it on these faces.
    def self.bake_color(instance)
      material = instance.material
      return unless material
      CircleRestore.inner_entities(instance).grep(Sketchup::Face).each do |f|
        f.material = material if f.material.nil?
      end
    end

    # Unique copy of a group or component instance in +entities+; the
    # component definitions made unique are listed in +created+.
    def self.duplicate(instance, entities, created)
      copy = if instance.is_a?(Sketchup::Group)
               instance.copy
             else
               entities.add_instance(instance.definition, instance.transformation)
             end
      copy.make_unique
      created << copy.definition if copy.is_a?(Sketchup::ComponentInstance)
      copy
    end

    # DefinitionList#remove exists from SketchUp 2018; before, the
    # definition is emptied, and SketchUp drops an empty definition that has
    # no instance.
    def self.remove_definition(model, definition)
      if model.definitions.respond_to?(:remove)
        model.definitions.remove(definition)
      else
        definition.entities.clear!
      end
    end

    # Restores the circles and arcs of +result+ on a copy: on failure the
    # copy is erased and the boolean result is kept as it is.
    # Returns [result, note, warning].
    def self.restore_circles(result, created)
      edge_count = CircleRestore.count_edges(result)
      threshold = SolidProcedural.large_threshold
      unless edge_count <= threshold || SolidProcedural.auto_repair_large == 'Yes'
        note = "circle restoration skipped (#{edge_count} edges > #{threshold})"
        warning = "Circle and arc restoration was skipped: the result contains #{edge_count} " \
                  "edges, which exceeds the configured threshold of #{threshold}.\n\n" \
                  "To enable repair on large objects, use 'Set Repair Options' and set " \
                  "'Auto-repair circles on large objects' to Yes."
        return [result, note, warning]
      end
      Sketchup.status_text = 'Solid Progress — Restoring circles and arcs...'
      trial = duplicate(result, result.parent.entities, created)
      # Group#copy does not keep the material of the instance.
      trial.material = result.material
      begin
        restored = CircleRestore.restore_in_solid(trial, min_arc_segments: SolidProcedural.min_arc_segments)
        puts "#{LOG}   Circles: #{CircleRestore.summary(restored, reasons: true)}"
        result.erase!
        [trial, CircleRestore.summary(restored), nil]
      rescue => e
        puts "#{LOG}   Circle restoration error: #{e.message}"
        e.backtrace.first(10).each { |line| puts "  #{line}" }
        trial.erase! if trial.valid?
        warning = "Circle and arc restoration failed: #{e.message}\n\n" \
                  'The boolean result is kept; its circles and arcs were left as they were.'
        [result, 'circle restoration failed', warning]
      end
    end

    # -------------------------------------------------------------------
    # Commands
    # -------------------------------------------------------------------

    # Shows the message and returns true when the plugin is set to SketchUp
    # Pro only (see ruby_engine?) and this SketchUp is not Pro.
    def self.pro_refused?
      ruby_engine?
      false
    rescue ProOnly => e
      UI.messagebox(e.message, MB_OK)
      true
    end

    def self.do_create
      model = Sketchup.active_model
      return if pro_refused?
      volumes = model.selection.select { |e| instance?(e) }
      if volumes.empty?
        UI.messagebox('Select the solid groups or components to combine in a Solid Progress group.', MB_OK)
        return
      end
      # A Solid Progress group is a volume too: its Result is used.
      not_solid = volumes.reject { |v| solid_volume?(v) }
      unless not_solid.empty?
        names = not_solid.map { |v| label(v) }.join(', ')
        UI.messagebox("These objects are not solids: #{names}.\n" \
                      'Repair or deselect them, then try again.', MB_OK)
        return
      end
      if volumes.all? { |v| SolidProcedural.is_subtract_solid?(v) }
        c = SolidProcedural.subtract_color
        UI.messagebox("No base volume found: all the selected objects have the subtract color " \
                      "RGB(#{c.red}, #{c.green}, #{c.blue}).\n" \
                      'At least one object must NOT have the subtract color.', MB_OK)
        return
      end

      # A result that is not a solid: only the volumes at fault stay
      # selected (the operation is cancelled, the volumes are back).
      select_at_fault = lambda do |edges|
        touching = touching_volumes(volumes.select(&:valid?), edges, Geom::Transformation.new)
        unless touching.empty?
          model.selection.clear
          model.selection.add(touching)
        end
      end
      run_command(model, 'Create Solid Progress', select_at_fault) do
        group = model.active_entities.add_group(volumes)
        group.name = DEFAULT_NAME
        group.set_attribute(DICT, 'role', ROLE_PROCEDURAL)
        # Initial order: every added volume, then every subtracted one.
        inside = group.entities.select { |e| instance?(e) }
        inside.each { |v| procedural?(v) ? clear_source_keys(v) : v.delete_attribute(DICT) }
        adds, subs = inside.partition { |v| !SolidProcedural.is_subtract_solid?(v) }
        (adds + subs).each_with_index { |v, i| v.set_attribute(DICT, 'rank', i + 1) }
        outcome = rebuild_in_operation(model, group)
        model.selection.clear
        model.selection.add(group)
        [outcome]
      end
    end

    def self.do_rebuild
      model = Sketchup.active_model
      return if pro_refused?
      groups = model.selection.select { |e| procedural?(e) }
      if groups.empty?
        message = if open_groups(model).empty?
                    'Select one or more Solid Progress groups to rebuild.'
                  else
                    "Close the Solid Progress group to rebuild it: it is rebuilt automatically " \
                    "when you exit it, if its volumes changed.\n" \
                    'To force a rebuild, close it, select it and run Rebuild again.'
                  end
        UI.messagebox(message, MB_OK)
        return
      end
      run_command(model, 'Rebuild Solid Progress') do
        groups.map { |g| rebuild_in_operation(model, g) }
      end
    end

    def self.do_finalize
      model = Sketchup.active_model
      return if pro_refused?
      groups = model.selection.select { |e| procedural?(e) }
      if groups.empty?
        UI.messagebox('Select one or more Solid Progress groups to finalize.', MB_OK)
        return
      end
      run_command(model, 'Finalize Solid Progress') do
        outcomes = []
        solids = groups.map do |g|
          outcomes << rebuild_in_operation(model, g) if stale?(g) || result_of(g).nil?
          finalize(g)
        end
        model.selection.clear
        model.selection.add(solids)
        outcomes
      end
    end

    # Replaces +group+ by its Result, a plain solid group. Returns it.
    def self.finalize(group)
      # A copied group shares its definition: make it unique before looking
      # up the Result, or the Result found belongs to the other copy.
      group.make_unique
      result = result_of(group)
      raise RebuildError, "'#{group_label(group)}' has no result to keep." unless result
      name = group.name
      layer = group.layer
      # Erase the sources first: exploding loose geometry would merge it
      # with the surrounding geometry.
      group.entities.erase_entities(group.entities.to_a - [result])
      solid = group.explode.find { |e| instance?(e) && e.valid? }
      raise RebuildError, "'#{group_label(group)}' could not be finalized." unless solid
      solid.delete_attribute(DICT)
      solid.hidden = false
      solid.name = name
      solid.layer = layer
      puts "#{LOG} Finalize '#{name}': done"
      solid
    end

    # Runs the block in one undoable operation. The block returns a list of
    # [note, warning]; warnings are shown once the operation is committed.
    # After a result that is not a solid, +on_fault+ gets its edges at fault.
    def self.run_command(model, title, on_fault = nil)
      model.start_operation("Solid Progress — #{title}", true)
      outcomes = yield
      model.commit_operation
      warnings = outcomes.map { |o| o[1] }.compact.uniq
      notes = outcomes.map { |o| o[0] }.compact
      Sketchup.status_text = "Solid Progress — #{title} done" +
                             (notes.empty? ? '' : " — #{notes.join('; ')}")
      UI.messagebox(warnings.join("\n\n"), MB_OK) unless warnings.empty?
    rescue RebuildError => e
      model.abort_operation
      puts "#{LOG} #{title}: #{e.message}"
      UI.messagebox("#{title} failed: #{e.message}\n\nNothing was changed.", MB_OK)
      if e.is_a?(NotSolidError)
        on_fault.call(e.edges) if on_fault && !e.edges.empty?
        FaultView.show(model, e.edges)
      end
    rescue => e
      model.abort_operation
      puts "#{LOG} #{title} error: #{e.message}"
      e.backtrace.first(10).each { |line| puts "  #{line}" }
      UI.messagebox("#{title} error: #{e.message}\n\nNothing was changed.", MB_OK)
    ensure
      # The selection changed by the command is not always notified to the
      # selection observer: the selection color is updated here too.
      Highlight.update_later
    end

    # -------------------------------------------------------------------
    # Procedural Table: rows and changes
    # -------------------------------------------------------------------

    # Table key of each source: its uid (set at each normalization and kept
    # by copies), or its entity ID while it has none or shares it.
    def self.row_keys(sources)
      used = {}
      sources.map do |s|
        key = s.get_attribute(DICT, 'uid')
        key = "id:#{s.entityID}" if key.nil? || used[key]
        used[key] = true
        key
      end
    end

    def self.row_lookup(group)
      sources = sources_of(group)
      Hash[row_keys(sources).zip(sources)]
    end

    # [text, level] of the State column; +base+ is the first row.
    def self.state_of(source, base)
      if procedural?(source)
        return ['Solid Progress: Result not a solid', 'error'] unless solid_volume?(source)
        return ['Disabled', 'off'] unless enabled?(source)
        return ['Base must be added', 'error'] if base && op_of(source) == 'subtract'
        return [stale?(source) ? 'Solid Progress: to rebuild' : 'Solid Progress', 'ok']
      end
      return ['Not solid', 'error'] unless source.manifold?
      return ['Disabled', 'off'] unless enabled?(source)
      return ['Base must be added', 'error'] if base && op_of(source) == 'subtract'
      ['Solid', 'ok']
    end

    # Applies a change of the table to +group+ in one undoable operation.
    # The block gets the sources in rank order and the table keys resolved
    # before the change; it returns the new order, or nil to keep it. A
    # closed group is rebuilt in the same operation when its signature
    # changed (an error cancels the change); an open one when it is closed.
    def self.change_table(model, group, title)
      run_command(model, title) do
        open = open_groups(model).include?(group)
        group.make_unique unless open
        lookup = row_lookup(group)
        sources = normalize_sources(group)
        order = yield(sources, lookup)
        order.each_with_index { |s, i| set_attribute(s, 'rank', i + 1) } if order
        outcomes = !open && stale?(group) ? [rebuild_in_operation(model, group)] : []
        # A nested group changed from the table of an outer one: the closed
        # groups that hold it are rebuilt too, from the inside out.
        procedural_parents(group).each do |parent|
          break if open_groups(model).include?(parent)
          outcomes << rebuild_in_operation(model, parent) if stale?(parent)
        end
        outcomes
      end
    end

    # The Solid Progress groups that hold +group+, innermost first.
    def self.procedural_parents(group)
      parents = []
      current = group
      loop do
        definition = current.parent
        break unless definition.is_a?(Sketchup::ComponentDefinition)
        current = definition.instances.find { |i| procedural?(i) }
        break unless current
        parents << current
      end
      parents
    end

    def self.table_source(lookup, key)
      lookup[key] || raise(RebuildError, 'The table was out of date: try again.')
    end

    def self.table_toggle(model, group, key, on)
      change_table(model, group, on ? 'Enable Volume' : 'Disable Volume') do |sources, lookup|
        source = table_source(lookup, key)
        if source == sources.first && !on
          raise RebuildError, 'The base volume is always enabled: make another volume the base first.'
        end
        set_attribute(source, 'enabled', on)
        nil
      end
    end

    # The volume of the row becomes the base (first row, enabled, added);
    # the former base comes second with its own operation.
    def self.table_set_base(model, group, key)
      change_table(model, group, 'Set Base') do |sources, lookup|
        source = table_source(lookup, key)
        if op_of(source) == 'subtract'
          set_operation(model, source, source.get_attribute(DICT, 'last_add_op') || 'union')
        end
        set_attribute(source, 'enabled', true)
        [source] + (sources - [source])
      end
    end

    def self.table_operation(model, group, key, op)
      change_table(model, group, "Set #{OP_LABELS[op]}") do |_sources, lookup|
        set_operation(model, table_source(lookup, key), op)
        nil
      end
    end

    # Color of +group+ (+name+: a material of the model, nil = default; or
    # +rgb+, '#RRGGBB': a material of that color, made if needed): shown by
    # its Result, no rebuild needed.
    def self.table_color(model, group, name, rgb = nil)
      change_table(model, group, 'Set Color') do |_sources, _lookup|
        material = rgb ? rgb_material(model, rgb) : name && model.materials[name]
        group.set_attribute(DICT, 'color', material ? material.name : 'none')
        apply_result_color(group)
        nil
      end
    end

    def self.table_rename(model, group, key, name)
      change_table(model, group, 'Rename Volume') do |_sources, lookup|
        table_source(lookup, key).name = name
        nil
      end
    end

    # The base stays first whatever the order received.
    def self.table_order(model, group, keys)
      change_table(model, group, 'Reorder Volumes') do |sources, lookup|
        next nil if sources.empty?
        base = sources.first
        wanted = keys.map { |k| lookup[k] }.compact.uniq - [base]
        [base] + wanted + (sources - wanted - [base])
      end
    end

    # The base, then every Union and Shell, then every Subtract, each in its
    # current order.
    def self.table_unions_first(model, group)
      change_table(model, group, 'Unions First') do |sources, _lookup|
        base, *others = sources
        adds, subs = others.partition { |s| op_of(s) != 'subtract' }
        base ? [base] + adds + subs : nil
      end
    end

    # Sets the operation of +source+ and keeps its color in line: Subtract
    # paints it with the subtract color; leaving Subtract, it is neutral
    # (default material) again.
    def self.set_operation(model, source, op)
      current = op_of(source)
      return if current == op
      if op == 'subtract'
        set_attribute(source, 'last_add_op', current)
        source.material = subtract_material(model)
      else
        source.material = nil if current == 'subtract'
        set_attribute(source, 'last_add_op', op)
      end
      set_attribute(source, 'op', op)
      # The color now matches the operation: no flip at the next rebuild.
      set_attribute(source, 'seen_color', material_key(source.material))
    end

    # A material of the color +rgb+ ('#RRGGBB') without texture, or a new
    # one; never the subtract color.
    def self.rgb_material(model, rgb)
      hex = rgb.to_s.sub(/\A#/, '').upcase
      raise RebuildError, "Not a color: #{rgb}." unless hex =~ /\A[0-9A-F]{6}\z/
      color = Sketchup::Color.new(*hex.scan(/../).map(&:hex))
      if SolidProcedural.color_match?(color, SolidProcedural.subtract_color)
        raise RebuildError, 'That is the subtract color: choose another one.'
      end
      existing = model.materials.find { |m| m.texture.nil? && SolidProcedural.color_match?(m.color, color) }
      return existing if existing
      material = model.materials.add("Solid Progress ##{hex}")
      material.color = color
      material
    end

    # A material of the subtract color without texture, or a new one.
    def self.subtract_material(model)
      color = SolidProcedural.subtract_color
      existing = model.materials.find do |m|
        m.texture.nil? && SolidProcedural.color_match?(m.color, color)
      end
      return existing if existing
      material = model.materials.add(SUBTRACT_MATERIAL_NAME)
      material.color = color
      material
    end

    # -------------------------------------------------------------------
    # Synchronization with the edit state (called by the observers,
    # deferred: never inside an observer callback)
    # -------------------------------------------------------------------

    # Active path changed: the groups left are rebuilt if their sources
    # changed, then show their Result; the groups entered show their
    # sources. The rebuild is appended to the last edit when
    # MERGE_REBUILD_WITH_LAST_EDIT; display changes are always transparent.
    def self.sync_path(model)
      current = open_groups(model)
      previous = (@synced_paths[model] || []).select(&:valid?)
      @synced_paths[model] = current
      left = (previous - current).reverse
      entered = current - previous
      stale = left.select { |g| stale?(g) }
      display = left.any? { |g| !display_changes(g, false).empty? } ||
                entered.any? { |g| !display_changes(g, true).empty? }
      return if stale.empty? && !display

      transparent = stale.empty? || MERGE_REBUILD_WITH_LAST_EDIT
      model.start_operation('Solid Progress — Rebuild', true, false, transparent)
      errors = []
      notes = []
      faults = []
      begin
        left.each do |g|
          if stale.include?(g)
            begin
              notes << "#{group_label(g)} rebuilt — #{rebuild_in_operation(model, g)[0]}"
            rescue RebuildError => e
              errors << "#{group_label(g)}: #{e.message}"
              faults.concat(e.edges) if e.is_a?(NotSolidError)
            end
          end
          apply_display(g, false)
          if loose_geometry?(g)
            notes << "#{group_label(g)}: loose geometry is not used, make it a group"
          end
        end
        entered.each { |g| apply_display(g, true) }
      rescue => e
        errors << "Unexpected error: #{e.message}"
        e.backtrace.first(10).each { |line| puts "  #{line}" }
      end
      model.commit_operation

      Sketchup.status_text = "Solid Progress — #{notes.join('; ')}" unless notes.empty?
      return if errors.empty?
      errors.each { |m| puts "#{LOG} #{m}" }
      UI.messagebox("Rebuild failed — the former result is kept.\n\n#{errors.join("\n")}", MB_OK)
      FaultView.show(model, faults)
    end

    # After Ctrl+Z / Ctrl+Y or when a model is opened: display of every
    # procedural group set back from the active path. Never rebuilds (a new
    # operation after an undo would drop the redo).
    def self.sync_all(model)
      current = open_groups(model)
      @synced_paths[model] = current
      groups = all_groups(model)
      changed = groups.reject { |g| display_changes(g, current.include?(g)).empty? }
      unless changed.empty?
        model.start_operation('Solid Progress — Display', true, false, true)
        changed.each { |g| apply_display(g, current.include?(g)) }
        model.commit_operation
      end
      outdated = (groups - current).select { |g| stale?(g) }
      return if outdated.empty?
      Sketchup.status_text = "Solid Progress — #{outdated.length} Solid Progress group(s) out of date: " \
                             'open and close them, or use Rebuild'
    end

    # Color chosen for +group+ (attribute color, see normalize_sources); a
    # material removed from the model since: the default material.
    def self.chosen_color(group)
      name = group.get_attribute(DICT, 'color')
      return initial_color(group) if name.nil?
      name == 'none' ? nil : group.model.materials[name]
    end

    # Color of a group that has none yet (made before 2.2.0): its paint
    # (not the subtract color), else the color of its base.
    def self.initial_color(group)
      return group.material if painted?(group)
      base = sources_of(group).first
      return nil unless base
      procedural?(base) ? chosen_color(base) : base.material
    end

    # Material of the Result: the color of the group, nested or not.
    # Painted with the subtract color (a tool), none: the Result shows the
    # subtract color of its group, as any subtracted volume.
    def self.result_material(group)
      return nil if subtract_material?(group.material)
      chosen_color(group)
    end

    def self.apply_result_color(group)
      result = result_of(group)
      return unless result && result.material != result_material(group)
      # A copied group shares its definition: the copy must not change too.
      group.make_unique
      result_of(group).material = result_material(group)
    end

    # Painted by hand, not with the subtract color (the only paint that
    # means something: subtract).
    def self.painted?(entity)
      !entity.material.nil? && !subtract_material?(entity.material)
    end

    # After an operation: colors are set in the Progress Table only. A paint
    # other than the subtract color is taken off at once: from a Solid
    # Progress group of the active context (it keeps the color of its
    # table; a group made before 2.2.0 takes the paint as its color), and
    # from a plain volume of an open Solid Progress group (neutral; its own
    # material, if it had none kept yet, given back when it leaves the
    # group). Results show the color of their group. In a transparent
    # operation appended to the operation.
    def self.sync_colors(model)
      path = model.active_path || []
      inside = !path.empty? && procedural?(path.last)
      groups = model.active_entities.select do |g|
        procedural?(g) && (result = result_of(g)) &&
          (painted?(g) || result.material != result_material(g))
      end
      volumes = model.active_entities.select do |e|
        inside && instance?(e) && !procedural?(e) && role(e) != ROLE_RESULT && painted?(e)
      end
      return if groups.empty? && volumes.empty?
      painted = groups.select { |g| painted?(g) } + volumes
      model.start_operation('Solid Progress — Color', true, false, true)
      painted.each do |e|
        if procedural?(e)
          e.set_attribute(DICT, 'color', e.material.name) unless e.get_attribute(DICT, 'color')
        elsif e.get_attribute(DICT, 'orig_material').nil?
          e.set_attribute(DICT, 'orig_material', e.material.name)
        end
        e.material = nil
      end
      groups.each { |g| apply_result_color(g) }
      model.commit_operation
      return if painted.empty?
      Sketchup.status_text = 'Solid Progress — colors are set in the Progress Table (header, or SP row); ' \
                             'paint with the subtract color to subtract'
    end

    # After an operation: the volumes left by an Explode of a procedural
    # solid (or pasted out of it) are shown and become plain objects, in a
    # transparent operation appended to the one that released them.
    def self.release_orphans(model)
      path = model.active_path || []
      return if !path.empty? && procedural?(path.last)
      # A nested Solid Progress group released stays a Solid Progress group.
      orphans = model.active_entities.select do |e|
        instance?(e) && ([ROLE_SOURCE, ROLE_RESULT].include?(role(e)) ||
                         (procedural?(e) && e.get_attribute(DICT, 'rank')))
      end
      return if orphans.empty?
      model.start_operation('Solid Progress — Release', true, false, true)
      orphans.each do |e|
        # A volume shown neutral gets its own material back.
        orig = e.get_attribute(DICT, 'orig_material')
        if orig && e.material.nil? && role(e) == ROLE_SOURCE && op_of(e) != 'subtract'
          e.material = model.materials[orig]
        end
        procedural?(e) ? clear_source_keys(e) : e.delete_attribute(DICT)
        e.hidden = false
      end
      model.commit_operation
      puts "#{LOG} #{orphans.length} volume(s) released from a Solid Progress group"
      Sketchup.status_text = "Solid Progress — #{orphans.length} volume(s) released: they are plain objects now"
    end
  end
end
