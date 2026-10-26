# encoding: UTF-8
# Solid Progress - images of the demo scenes (development tool).
# Started by tools/tests/run_tests.ps1 -Demo: builds the demo in the new
# model of SketchUp (as File > New, then load build_demo.rb would), writes
# one image per scene in tools/tests/results/demo-<major>-<n>.png, writes
# results/demo.skp and results/demo-2017.skp (SketchUp 2021 or later, as
# Demo.save), then the report results/demo-<major>.txt. Message boxes are
# written in the report instead of shown.

sp_demo_timer = UI.start_timer(1, false) do
  UI.stop_timer(sp_demo_timer)
  results = File.expand_path('../tests/results', File.dirname(File.expand_path(__FILE__)))
  major = Sketchup.version.to_i
  lines = []
  messages = []
  UI.define_singleton_method(:messagebox) do |*args|
    messages << args.first.to_s
    1
  end
  begin
    $sp_demo_no_autorun = true
    load File.join(File.dirname(File.expand_path(__FILE__)), 'build_demo.rb')
    $sp_demo_no_autorun = nil
    SolidProcedural::Demo.start
    model = Sketchup.active_model
    view = model.active_view
    model.pages.to_a.each_with_index do |page, k|
      view.camera = page.camera
      file = File.join(results, "demo-#{major}-#{k}.png")
      lines << "#{page.name}: #{view.write_image(file) ? file : 'image not written'}"
    end
    if major >= 21
      saved = SolidProcedural::Demo.save
      lines << (saved ? 'results/demo.skp and results/demo-2017.skp written' : 'demo files not written')
    end
  rescue => e
    messages << "#{e.class}: #{e.message} | #{e.backtrace.first(4).join(' | ')}"
  end
  lines.concat(messages.map { |m| "MESSAGE #{m}" })
  lines << format('DONE  scenes=%d failed=%d ', model ? model.pages.size : 0, messages.empty? ? 0 : 1)
  File.open(File.join(results, "demo-#{major}.txt"), 'w:UTF-8') { |f| f.puts lines }
  puts lines
end
