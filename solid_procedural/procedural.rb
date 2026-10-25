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
  #                volume leaves Subtract in the Procedural Table
  #   uid          key of the volume in the Procedural Table, kept by copies
  # The group stores the signature (MD5) of its sources at the last rebuild:
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
    DEFAULT_NAME = 'Procedural Solid'.freeze
    RESULT_NAME = 'Result'.freeze
    SUBTRACT_MATERIAL_NAME = 'Solid Procedural Subtract'.freeze
    LOG = '[Solid Procedural]'.freeze

    # true (option B): the automatic rebuild on exit is appended to the last
    # edit (transparent operation), so one Ctrl+Z undoes the edit and its
    # result. false (option A): separate undo step.
    MERGE_REBUILD_WITH_LAST_EDIT = true

    # Message for the user; the rebuild that raised it changed no geometry
    # and kept the former Result.
    class RebuildError < StandardError; end

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
      end
      sources
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
        if procedural?(s)
          raise RebuildError, "Volume #{label(s)} is a procedural solid: " \
                              'nested procedural solids are not supported yet.'
        end
        raise RebuildError, "Volume #{label(s)} is not a solid." unless s.manifold?
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
      selected = model.selection.to_a
      group.make_unique
      sources = normalize_sources(group)
      active = sources.select { |s| enabled?(s) }
      validate(active)
      sig = signature(group)
      puts "#{LOG} Rebuild '#{group_label(group)}': #{active.length} volume(s)"

      if loose_geometry?(group)
        puts "#{LOG}   Loose geometry ignored: make it a group to use it as a volume"
      end

      created = []
      begin
        copies = []
        result = nil
        begin
          result = combine(model, group, active, copies, created)
        ensure
          copies.each { |c| c.erase! if c.valid? && c != result }
        end

        result.material = active.first.material
        result.entities.grep(Sketchup::Face).each do |f|
          f.material = nil if subtract_material?(f.material)
          f.back_material = nil if subtract_material?(f.back_material)
        end
        result, note, warning = restore_circles(result, created)
      ensure
        created.each do |d|
          model.definitions.remove(d) if d.valid? && d.count_instances.zero?
        end
      end

      old = result_of(group)
      old.erase! if old
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
      entities = group.entities
      acc = copy_of(active.first, entities, created)
      copies << acc
      total = active.length - 1
      active.drop(1).each_with_index do |source, i|
        op = op_of(source)
        pct = ((i + 1) * 100.0 / total).round
        Sketchup.status_text = "Solid Procedural — #{OP_LABELS[op]} #{i + 1}/#{total} (#{pct}%)"
        copy = copy_of(source, entities, created)
        copies << copy
        model.selection.clear
        # Native subtract: tool.subtract(base) subtracts the tool from the
        # base, erases the tool and returns the modified base.
        res = case op
              when 'union' then acc.union(copy)
              when 'outer_shell' then acc.outer_shell(copy)
              else copy.subtract(acc)
              end
        unless res && res.valid?
          raise RebuildError, "#{OP_LABELS[op]} of volume #{label(source)} failed."
        end
        copies << res
        acc = res
      end
      acc
    end

    # Visible copy of +source+ in +entities+, with its own definition (a
    # copy shares the definition of its source, which a boolean would then
    # modify too) and without the procedural attributes.
    def self.copy_of(source, entities, created)
      copy = duplicate(source, entities, created)
      copy.material = source.material
      copy.hidden = false
      copy.delete_attribute(DICT)
      copy
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
      Sketchup.status_text = 'Solid Procedural — Restoring circles and arcs...'
      trial = duplicate(result, result.parent.entities, created)
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

    def self.do_create
      model = Sketchup.active_model
      volumes = model.selection.select { |e| instance?(e) }
      if volumes.empty?
        UI.messagebox('Select the solid groups or components to combine in a procedural solid.', MB_OK)
        return
      end
      unless volumes.first.respond_to?(:union)
        UI.messagebox("This function requires SketchUp Pro.\n" \
                      "The native boolean methods are not available in your version.", MB_OK)
        return
      end
      nested = volumes.select { |v| procedural?(v) }
      unless nested.empty?
        UI.messagebox('Nested procedural solids are not supported yet: ' \
                      'deselect the procedural solids.', MB_OK)
        return
      end
      not_solid = volumes.reject(&:manifold?)
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

      run_command(model, 'Create Procedural Solid') do
        group = model.active_entities.add_group(volumes)
        group.name = DEFAULT_NAME
        group.set_attribute(DICT, 'role', ROLE_PROCEDURAL)
        # Initial order: every added volume, then every subtracted one.
        inside = group.entities.select { |e| instance?(e) }
        inside.each { |v| v.delete_attribute(DICT) }
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
      groups = model.selection.select { |e| procedural?(e) }
      if groups.empty?
        message = if open_groups(model).empty?
                    'Select one or more procedural solids to rebuild.'
                  else
                    "Close the procedural solid to rebuild it: it is rebuilt automatically " \
                    "when you exit it, if its volumes changed.\n" \
                    'To force a rebuild, close it, select it and run Rebuild again.'
                  end
        UI.messagebox(message, MB_OK)
        return
      end
      run_command(model, 'Rebuild Procedural Solid') do
        groups.map { |g| rebuild_in_operation(model, g) }
      end
    end

    def self.do_finalize
      model = Sketchup.active_model
      groups = model.selection.select { |e| procedural?(e) }
      if groups.empty?
        UI.messagebox('Select one or more procedural solids to finalize.', MB_OK)
        return
      end
      run_command(model, 'Finalize Procedural Solid') do
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
    def self.run_command(model, title)
      model.start_operation("Solid Procedural — #{title}", true)
      outcomes = yield
      model.commit_operation
      warnings = outcomes.map { |o| o[1] }.compact.uniq
      notes = outcomes.map { |o| o[0] }.compact
      Sketchup.status_text = "Solid Procedural — #{title} done" +
                             (notes.empty? ? '' : " — #{notes.join('; ')}")
      UI.messagebox(warnings.join("\n\n"), MB_OK) unless warnings.empty?
    rescue RebuildError => e
      model.abort_operation
      puts "#{LOG} #{title}: #{e.message}"
      UI.messagebox("#{title} failed: #{e.message}\n\nNothing was changed.", MB_OK)
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
      return ['Nested: not supported yet', 'error'] if procedural?(source)
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
        !open && stale?(group) ? [rebuild_in_operation(model, group)] : []
      end
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
    # paints it with the subtract color and keeps its former material, which
    # comes back when it leaves Subtract.
    def self.set_operation(model, source, op)
      current = op_of(source)
      return if current == op
      if op == 'subtract'
        set_attribute(source, 'prev_material', source.material ? source.material.name : 'none')
        set_attribute(source, 'last_add_op', current)
        source.material = subtract_material(model)
      else
        if current == 'subtract'
          prev = source.get_attribute(DICT, 'prev_material')
          material = prev && prev != 'none' ? model.materials[prev] : nil
          source.material = subtract_material?(material) ? nil : material
        end
        set_attribute(source, 'last_add_op', op)
      end
      set_attribute(source, 'op', op)
      # The color now matches the operation: no flip at the next rebuild.
      set_attribute(source, 'seen_color', material_key(source.material))
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
      model.start_operation('Solid Procedural — Rebuild', true, false, transparent)
      errors = []
      notes = []
      begin
        left.each do |g|
          if stale.include?(g)
            begin
              notes << "#{group_label(g)} rebuilt — #{rebuild_in_operation(model, g)[0]}"
            rescue RebuildError => e
              errors << "#{group_label(g)}: #{e.message}"
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

      Sketchup.status_text = "Solid Procedural — #{notes.join('; ')}" unless notes.empty?
      return if errors.empty?
      errors.each { |m| puts "#{LOG} #{m}" }
      UI.messagebox("Rebuild failed — the former result is kept.\n\n#{errors.join("\n")}", MB_OK)
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
        model.start_operation('Solid Procedural — Display', true, false, true)
        changed.each { |g| apply_display(g, current.include?(g)) }
        model.commit_operation
      end
      outdated = (groups - current).select { |g| stale?(g) }
      return if outdated.empty?
      Sketchup.status_text = "Solid Procedural — #{outdated.length} procedural solid(s) out of date: " \
                             'open and close them, or use Rebuild'
    end

    # After an operation: the volumes left by an Explode of a procedural
    # solid (or pasted out of it) are shown and become plain objects, in a
    # transparent operation appended to the one that released them.
    def self.release_orphans(model)
      path = model.active_path || []
      return if !path.empty? && procedural?(path.last)
      orphans = model.active_entities.select do |e|
        instance?(e) && [ROLE_SOURCE, ROLE_RESULT].include?(role(e))
      end
      return if orphans.empty?
      model.start_operation('Solid Procedural — Release', true, false, true)
      orphans.each do |e|
        e.delete_attribute(DICT)
        e.hidden = false
      end
      model.commit_operation
      puts "#{LOG} #{orphans.length} volume(s) released from a procedural solid"
      Sketchup.status_text = "Solid Procedural — #{orphans.length} volume(s) released: they are plain objects now"
    end
  end
end
