# encoding: UTF-8

module SolidProcedural
  module Procedural
    # Observers of the edit state. The API forbids changing the model inside
    # an observer callback: every change is deferred with UI.start_timer and
    # runs once SketchUp is idle (Procedural.sync_path / sync_all /
    # release_orphans). The Procedural Table is refreshed the same way.
    class ModelObserver < Sketchup::ModelObserver
      # The user opened or closed a group or component for editing.
      def onActivePathChanged(model)
        Procedural.defer(model, :path)
        ProceduralTable.refresh_later
        Highlight.update_later
      end

      def onTransactionCommit(model)
        Procedural.defer(model, :commit)
        ProceduralTable.refresh_later
      end

      def onTransactionUndo(model)
        Procedural.defer(model, :all)
        ProceduralTable.refresh_later
        Highlight.update_later
      end

      def onTransactionRedo(model)
        Procedural.defer(model, :all)
        ProceduralTable.refresh_later
        Highlight.update_later
      end

      # The green selection color is never saved.
      def onPreSaveModel(model)
        Highlight.before_save(model)
      end

      def onPostSaveModel(_model)
        Highlight.update_later
      end
    end

    # Selection changes: highlight of the rows of the Procedural Table and
    # green selection color. onSelectionAdded / Removed are not always
    # notified: all four are used.
    class SelectionObserver < Sketchup::SelectionObserver
      def onSelectionBulkChange(_selection)
        selection_changed
      end

      def onSelectionCleared(_selection)
        selection_changed
      end

      def onSelectionAdded(_selection, _entity)
        selection_changed
      end

      def onSelectionRemoved(_selection, _entity)
        selection_changed
      end

      private

      def selection_changed
        ProceduralTable.refresh_later
        Highlight.update_later
      end
    end

    # Attaches the model observer to the models created or opened.
    class AppObserver < Sketchup::AppObserver
      def onNewModel(model)
        Procedural.attach(model)
      end

      def onOpenModel(model)
        Procedural.attach(model)
      end

      # Also notified for the models open at startup.
      def expectsStartupModelNotifications
        true
      end
    end

    # Synchronizations requested and not run yet, per model.
    @pending ||= {}
    @attached ||= {}

    def self.attach(model)
      return unless model
      @model_observer ||= ModelObserver.new
      @selection_observer ||= SelectionObserver.new
      # SketchUp 2017 keeps the same Model object when a file is opened, but
      # drops its observers: attach them again each time, never twice.
      model.remove_observer(@model_observer)
      model.add_observer(@model_observer)
      model.selection.remove_observer(@selection_observer)
      model.selection.add_observer(@selection_observer)
      @attached[model] = true
      # The original selection color kept was the one of the former document.
      Highlight.forget(model)
      @synced_paths[model] = open_groups(model)
      # A model saved while a procedural solid was open shows its sources.
      defer(model, :all)
      ProceduralTable.refresh_later
    end

    # Runs the requested synchronizations once, after the callback.
    def self.defer(model, kind)
      return if @busy
      kinds = (@pending[model] ||= [])
      kinds << kind unless kinds.include?(kind)
      return unless kinds.length == 1
      timer = UI.start_timer(0, false) do
        # A non-repeating timer that shows a modal dialog fires again while
        # the dialog is open: stop it first.
        UI.stop_timer(timer)
        run(model, @pending.delete(model) || [])
      end
    end

    def self.run(model, kinds)
      return unless model.valid?
      @busy = true
      sync_path(model) if kinds.include?(:path)
      if kinds.include?(:all)
        sync_all(model)
        Highlight.repair(model)
      end
      release_orphans(model) if kinds.include?(:commit)
    rescue => e
      puts "[Solid Progress] Synchronization error: #{e.message}"
      e.backtrace.first(10).each { |line| puts "  #{line}" }
    ensure
      @busy = false
    end

    unless @app_observer
      @app_observer = AppObserver.new
      Sketchup.add_observer(@app_observer)
    end
    attach(Sketchup.active_model)
  end
end
