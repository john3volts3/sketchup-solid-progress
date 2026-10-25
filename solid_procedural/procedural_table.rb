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
    HTML_FILE = File.join(PLUGIN_DIR, 'solid_procedural', 'html', 'procedural_table.html').freeze
    LOG = '[Solid Procedural]'.freeze
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
        dialog_title: "#{PLUGIN_NAME} — Procedural Table",
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

    # Procedural solid shown: the innermost open one, else the only one
    # selected.
    def self.target_group(model)
      return nil unless model
      open = Procedural.open_groups(model).last
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
                 message: many ? 'Select a single procedural solid.' : 'Select or open a procedural solid.' }
      end
      sources = Procedural.sources_of(group)
      keys = Procedural.row_keys(sources)
      path = model.active_path || []
      # The first row is the base, always enabled (Procedural.normalize_sources).
      base = sources.first
      rows = sources.each_with_index.map do |s, i|
        state, level = Procedural.state_of(s, s == base)
        {
          key: keys[i],
          position: i + 1,
          name: s.name.to_s,
          placeholder: s.definition.name.to_s,
          enabled: Procedural.enabled?(s),
          op: Procedural.op_of(s),
          base: s == base,
          color: color_hex(s.material),
          state: state,
          level: level,
          selected: model.selection.include?(s) || path.include?(s)
        }
      end
      { group: group.entityID, name: Procedural.group_label(group), open: path.include?(group), rows: rows }
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
      group = target_group(model)
      # The page shows another solid than the model now: refresh only.
      if group.nil? || group.entityID != data['group']
        refresh
        return
      end
      case data['type']
      when 'select'
        select_row(model, group, data['key'])
      when 'open'
        open_row(model, group, data['key'])
      when 'toggle'
        Procedural.table_toggle(model, group, data['key'], data['on'] == true)
      when 'op'
        Procedural.table_operation(model, group, data['key'], data['op']) if OPERATIONS.include?(data['op'])
      when 'base'
        Procedural.table_set_base(model, group, data['key'])
      when 'rename'
        Procedural.table_rename(model, group, data['key'], data['name'].to_s.strip)
      when 'order'
        Procedural.table_order(model, group, Array(data['keys']))
      when 'unions_first'
        Procedural.table_unions_first(model, group)
      end
      refresh_later
    rescue => e
      puts "#{LOG} Table action error: #{e.message}"
      e.backtrace.first(10).each { |line| puts "  #{line}" }
      refresh_later
    end

    # Selects the volume of a row when its procedural solid is open; when
    # a source of it is being edited, its context is closed first.
    def self.select_row(model, group, key)
      source = Procedural.row_lookup(group)[key]
      path = model.active_path || []
      return unless source && path.include?(group)
      unless path.last == group
        return status_no_active_path('Close the edited volume first') unless active_path_settable?(model)
        model.active_path = path[0..path.index(group)]
      end
      model.selection.clear
      model.selection.add(source)
    end

    # Double-click: opens the procedural solid if needed, then selects the
    # volume.
    def self.open_row(model, group, key)
      path = model.active_path || []
      unless path.include?(group)
        context = path.empty? ? model : path.last.definition
        return unless group.parent == context
        return status_no_active_path('Double-click the procedural solid in the model to open it') unless active_path_settable?(model)
        model.active_path = path + [group]
      end
      select_row(model, group, key)
    end

    # Model#active_path= exists from SketchUp 2020.
    def self.active_path_settable?(model)
      model.respond_to?(:active_path=)
    end

    def self.status_no_active_path(text)
      Sketchup.status_text = "Solid Procedural — #{text} (not available from the table in this SketchUp version)"
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
