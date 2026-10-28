# encoding: UTF-8
require 'json'

module SolidProcedural
  # Procedural Table — the operation list of a procedural solid in an
  # HtmlDialog: order, On, color, name, operation and state of each source
  # volume, formula, Unions first, selection in both directions.
  #
  # The table shows the innermost open procedural solid, else the selected
  # one. It never changes the model by itself: each action of the page is
  # one undoable operation (Procedural.change_table), and the page is
  # refreshed, deferred, after every change of the model or the selection.
  # After an action, the page gives the keyboard back to SketchUp, so that
  # its shortcuts keep working while the table is open.
  module ProceduralTable
    HTML_FILE = File.join(PLUGIN_DIR, 'solid_progress', 'html', 'procedural_table.html').freeze
    LOG = '[Solid Progress]'.freeze
    OPERATIONS = %w[union outer_shell subtract].freeze

    # Windows API through Fiddle (Ruby standard library), to give the
    # keyboard back to SketchUp before Sketchup.focus (SketchUp 2021.1).
    # Nothing is done on macOS or when the API cannot be loaded.
    module Win32
      GA_ROOTOWNER = 3

      def self.functions
        return @functions if defined?(@functions)
        @functions = nil
        return nil unless Sketchup.platform == :platform_win
        require 'fiddle'
        user32 = Fiddle.dlopen('user32')
        function = lambda do |name, args, result|
          Fiddle::Function.new(user32[name], args, result)
        end
        @functions = {
          foreground: function.call('GetForegroundWindow', [], Fiddle::TYPE_VOIDP),
          root_owner: function.call('GetAncestor', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_VOIDP),
          process: function.call('GetWindowThreadProcessId', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT),
          activate: function.call('SetForegroundWindow', [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
        }
      rescue LoadError, StandardError => e
        puts "#{LOG} Windows API not available: #{e.message}"
        @functions = nil
      end

      # Top-level window of SketchUp when it is in the foreground, else nil.
      def self.sketchup_window
        f = functions
        return nil unless f
        window = f[:foreground].call.to_i
        return nil if window.zero?
        root = f[:root_owner].call(window, GA_ROOTOWNER).to_i
        root = window if root.zero?
        pid = Fiddle::Pointer.malloc(4, Fiddle::RUBY_FREE)
        f[:process].call(root, pid)
        pid[0, 4].unpack('L').first == Process.pid ? root : nil
      end

      def self.activate(window)
        f = functions
        f[:activate].call(window) if f && window
      end
    end

    def self.show
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end
      # Opened from SketchUp (menu, toolbar, context menu): its window is
      # the one to give the keyboard back to.
      @main_window = Win32.sketchup_window unless Sketchup.respond_to?(:focus)
      @ready = false
      @dialog = UI::HtmlDialog.new(
        dialog_title: "#{PLUGIN_NAME} — Progress Table",
        preferences_key: 'SolidProcedural_ProceduralTable',
        scrollable: false,
        resizable: true,
        width: 620,
        height: 340,
        min_width: 460,
        min_height: 180,
        style: UI::HtmlDialog::STYLE_UTILITY
      )
      @dialog.set_file(HTML_FILE)
      @dialog.add_action_callback('action') { |_context, message| on_action(message) }
      @dialog.set_on_closed do
        @dialog = nil
        @ready = false
      end
      @dialog.show
    end

    # Procedural solid shown: the outermost open one (the whole tree stays in
    # view while a nested one is edited), else the only one selected.
    def self.target_group(model)
      return nil unless model
      open = Procedural.open_groups(model).first
      return open if open
      selected = model.selection.select { |e| Procedural.procedural?(e) }
      selected.length == 1 ? selected.first : nil
    end

    # -------------------------------------------------------------------
    # Ruby -> page
    # -------------------------------------------------------------------

    # Refresh once SketchUp is idle; several requests make one refresh.
    def self.refresh_later
      return unless @dialog && @ready
      return if @refresh_pending
      @refresh_pending = true
      timer = UI.start_timer(0, false) do
        UI.stop_timer(timer)
        @refresh_pending = false
        refresh
      end
    end

    def self.refresh
      return unless @dialog && @ready
      json = JSON.generate(payload(Sketchup.active_model))
      # Line separators are valid in JSON, not in a JavaScript string.
      json = json.gsub(" ", ' ').gsub(" ", ' ')
      @dialog.execute_script("SolidProcedural.update(#{json});")
    rescue => e
      puts "#{LOG} Table refresh error: #{e.message}"
      e.backtrace.first(5).each { |line| puts "  #{line}" }
    end

    def self.payload(model)
      group = target_group(model)
      unless group
        many = model && model.selection.count { |e| Procedural.procedural?(e) } > 1
        return { group: nil,
                 message: many ? 'Select a single Solid Progress group.' : 'Select or open a Solid Progress group.' }
      end
      path = model.active_path || []
      rows = table_rows(model, group, path, 0, '', nil)
      notice = @notice && @notice[0] == group ? @notice[1] : nil
      # Breadcrumb: the open Solid Progress groups, outermost first; the rows
      # of the innermost one are the ones being edited.
      opened = Procedural.open_groups(model)
      current = opened.last
      rows.each { |r| r[:current] = !current.nil? && r[:group] == current.entityID }
      # Inside the group of the table with no row of its own being edited:
      # the header and the breadcrumb say where you are.
      at_top = path.include?(group) && here_of(path).nil?
      { group: group.entityID, name: Procedural.group_label(group), open: path.include?(group), rows: rows, at_top: at_top,
        notice: notice, path: opened.map { |g| { group: g.entityID, name: Procedural.group_label(g) } },
        current: current && Procedural.group_label(current), materials: material_list(model) }
    end

    # Colors offered for a Solid Progress group: the materials of the model,
    # but the subtract color.
    def self.material_list(model)
      model.materials.reject { |m| Procedural.subtract_material?(m) }
           .map { |m| { name: m.name, label: m.display_name, color: color_hex(m) } }
           .sort_by { |m| m[:label].downcase }
    end

    # Rows of +group+; under the row of a nested Solid Progress group, the
    # rows of that group (depth + 1, numbered "2.1", "2.2"…). Each row names
    # the group it belongs to: its actions apply to that group.
    def self.table_rows(model, group, path, depth, prefix, parent)
      sources = Procedural.sources_of(group)
      keys = Procedural.row_keys(sources)
      # The first row is the base, always enabled (Procedural.normalize_sources).
      base = sources.first
      sources.each_with_index.flat_map do |s, i|
        state, level = Procedural.state_of(s, s == base)
        label = "#{prefix}#{i + 1}"
        id = "#{group.entityID}:#{keys[i]}"
        nested = Procedural.procedural?(s)
        row = {
          key: keys[i],
          group: group.entityID,
          id: id,
          parent: parent,
          depth: depth,
          nested: nested,
          # A nested group being edited: its rows are never folded.
          in_path: nested && path.include?(s),
          position: i + 1,
          label: label,
          name: s.name.to_s,
          placeholder: s.definition.name.to_s,
          enabled: Procedural.enabled?(s),
          op: Procedural.op_of(s),
          base: s == base,
          # The base row shows the color of its group, a nested group its
          # own color (the plain volumes are neutral or subtract).
          color: color_hex(row_color(group, s, s == base)),
          color_name: s == base ? color_label(Procedural.chosen_color(group)) : nil,
          state: state,
          level: level,
          # Only the volume selected in the model: the open groups are in_path.
          selected: model.selection.include?(s),
          # Where you are: the innermost volume or nested group opened.
          here: s == here_of(path)
        }
        [row] + (nested ? table_rows(model, s, path, depth + 1, "#{label}.", id) : [])
      end
    end

    # The innermost entity of +path+ that is a row of the table: a volume
    # (plain or nested Solid Progress group) opened in a Solid Progress
    # group; nil when only the Solid Progress groups themselves are open.
    def self.here_of(path)
      path.each_cons(2).map { |outer, inner| inner if Procedural.procedural?(outer) }.compact.last
    end

    # The groups from +group+ down to the Solid Progress group nested in it
    # whose entityID is +id+ ([group] for itself), or nil.
    def self.chain_to(group, id)
      return [group] if group.entityID == id
      Procedural.sources_of(group).each do |s|
        next unless Procedural.procedural?(s)
        chain = chain_to(s, id)
        return [group] + chain if chain
      end
      nil
    end

    def self.row_color(group, source, base)
      return Procedural.chosen_color(group) if base
      return Procedural.result_material(source) if Procedural.procedural?(source) && Procedural.op_of(source) != 'subtract'
      source.material
    end

    def self.color_label(material)
      material ? material.display_name : 'Default'
    end

    def self.color_hex(material)
      return nil unless material
      c = material.color
      format('#%02x%02x%02x', c.red, c.green, c.blue)
    end

    # -------------------------------------------------------------------
    # Page -> Ruby
    # -------------------------------------------------------------------

    def self.on_action(message)
      data = JSON.parse(message.to_s)
      model = Sketchup.active_model
      if data['type'] == 'ready'
        @ready = true
        refresh
        return
      end
      if data['type'] == 'focus'
        focus_sketchup
        return
      end
      @notice = nil
      table = target_group(model)
      # The group of the row: the one of the table or one nested in it.
      chain = table && chain_to(table, data['group'])
      # The page shows another solid than the model now: refresh only.
      unless chain
        refresh
        return
      end
      group = chain.last
      case data['type']
      when 'select'
        select_row(model, group, data['key'], table)
      when 'open'
        open_row(model, chain, data['key'])
      when 'toggle'
        Procedural.table_toggle(model, group, data['key'], data['on'] == true)
      when 'op'
        Procedural.table_operation(model, group, data['key'], data['op']) if OPERATIONS.include?(data['op'])
      when 'base'
        Procedural.table_set_base(model, group, data['key'])
      when 'rename'
        Procedural.table_rename(model, group, data['key'], data['name'].to_s.strip)
      when 'color'
        Procedural.table_color(model, group, data['material'].is_a?(String) ? data['material'] : nil,
                               data['rgb'].is_a?(String) ? data['rgb'] : nil)
      when 'order'
        Procedural.table_order(model, group, Array(data['keys']))
      when 'unions_first'
        Procedural.table_unions_first(model, group)
      when 'finalize'
        finalize_group(model, group)
      when 'close_to'
        close_to(model, chain.first, group)
      when 'close'
        # One level back: the innermost open Solid Progress group closes;
        # at the top level, the last one.
        opened = Procedural.open_groups(model)
        close_to(model, chain.first, opened.length > 1 ? opened[-2] : nil)
      end
      refresh_later
    rescue => e
      puts "#{LOG} Table action error: #{e.message}"
      e.backtrace.first(10).each { |line| puts "  #{line}" }
      refresh_later
    end

    # Selects the volume of a row when its procedural solid is open; when
    # a source of it is being edited, its context is closed first.
    # Click: selects the volume when its group is open (the groups opened
    # inside it close); else says how to reach it. +table+: the group of the
    # table, which shows the notice.
    def self.select_row(model, group, key, table = group)
      source = Procedural.row_lookup(group)[key]
      path = model.active_path || []
      return unless source
      unless path.include?(group)
        @notice = [table, active_path_settable?(model) ?
          'Double-click the row to open its group and select the volume.' :
          'Open its group in the model to select the volume.']
        return
      end
      unless path.last == group
        return status_no_active_path(table, 'Close the edited volume first') unless active_path_settable?(model)
        model.active_path = path[0..path.index(group)]
      end
      model.selection.clear
      model.selection.add(source)
    end

    # Double-click: opens the procedural solid if needed, then selects the
    # volume. +chain+: the groups from the one of the table down to the one
    # of the row (nested rows open every group of the chain).
    def self.open_row(model, chain, key)
      group = chain.last
      path = model.active_path || []
      missing = chain.reject { |g| path.include?(g) }
      unless missing.empty?
        context = path.empty? ? model : path.last.definition
        return unless missing.first.parent == context
        return status_no_active_path(chain.first, 'Double-click the Solid Progress group in the model to open it') unless active_path_settable?(model)
        model.active_path = path + missing
      end
      select_row(model, group, key, chain.first)
    end

    # Finalize button: the procedural solid shown, closed (the button is
    # greyed while it is open: SketchUp 2017 cannot close it from a
    # plugin). Shown closed, it is the only procedural solid selected.
    def self.finalize_group(model, group)
      if (model.active_path || []).include?(group)
        @notice = [group, 'Close the Solid Progress group to finalize it.']
        return
      end
      Procedural.do_finalize
    end

    # Breadcrumb: closes the Solid Progress groups opened inside +group+
    # (it stays open), or every one of them when +group+ is nil. The groups
    # left are rebuilt as on any exit (Procedural.sync_path).
    def self.close_to(model, table, group)
      path = model.active_path || []
      first = path.index { |e| Procedural.procedural?(e) }
      return unless first && (group.nil? || path.include?(group))
      return status_no_active_path(table, 'Click outside the Solid Progress group to close it') unless active_path_settable?(model)
      keep = group ? path[0..path.index(group)] : path[0...first]
      model.active_path = keep.empty? ? nil : keep
    rescue ArgumentError, TypeError
      model.active_path = []
    end

    # Model#active_path= exists from SketchUp 2020.
    def self.active_path_settable?(model)
      model.respond_to?(:active_path=)
    end

    def self.status_no_active_path(group, text)
      message = "#{text} (not available from the table in this SketchUp version)"
      Sketchup.status_text = "Solid Progress — #{message}"
      # Also shown in the table, until its next action.
      @notice = [group, "#{message}."]
      nil
    end

    # Keyboard back to SketchUp (the page asks for it after each action):
    # Sketchup.focus, else the Windows API on the window noted when the
    # table was opened, or on the owner of the table.
    def self.focus_sketchup
      if Sketchup.respond_to?(:focus)
        Sketchup.focus
      else
        Win32.activate(@main_window || Win32.sketchup_window)
      end
    end
  end
end
