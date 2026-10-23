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
  module ProceduralTable
    HTML_FILE = File.join(PLUGIN_DIR, 'solid_procedural', 'html', 'procedural_table.html').freeze
    LOG = '[Solid Procedural]'.freeze
    OPERATIONS = %w[union outer_shell subtract].freeze

    def self.show
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end
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
      base = sources.find { |s| Procedural.enabled?(s) }
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
      model.active_path = path[0..path.index(group)] unless path.last == group
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
        model.active_path = path + [group]
      end
      select_row(model, group, key)
    end
  end
end
