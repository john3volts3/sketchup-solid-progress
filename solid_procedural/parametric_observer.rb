# encoding: UTF-8

module SolidProcedural
  module Parametric
    # Observers of the edit state. The API forbids changing the model inside
    # an observer callback: every change is deferred with UI.start_timer and
    # runs once SketchUp is idle (Parametric.sync_path / sync_all).
    class ModelObserver < Sketchup::ModelObserver
      # The user opened or closed a group or component for editing.
      def onActivePathChanged(model)
        Parametric.defer(model, :path)
      end

      def onTransactionUndo(model)
        Parametric.defer(model, :all)
      end

      def onTransactionRedo(model)
        Parametric.defer(model, :all)
      end
    end

    # Attaches the model observer to the models created or opened.
    class AppObserver < Sketchup::AppObserver
      def onNewModel(model)
        Parametric.attach(model)
      end

      def onOpenModel(model)
        Parametric.attach(model)
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
      return if @attached[model]
      model.add_observer(@model_observer)
      @attached[model] = true
      @synced_paths[model] = open_groups(model)
      # A model saved while a parametric solid was open shows its sources.
      defer(model, :all)
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
      sync_all(model) if kinds.include?(:all)
    rescue => e
      puts "[Solid Procedural] Synchronization error: #{e.message}"
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
