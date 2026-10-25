# encoding: UTF-8
# Solid Procedural - manual test of onActivePathChanged (development tool).
# Started by tools/tests/run_tests.ps1 -Manual: creates "SP Test - open me",
# then waits for the user to double-click it and to exit it, and writes
# results/manual-<SketchUp major version>.txt.

$sp_tests_no_autorun = true
load File.join(File.dirname(File.expand_path(__FILE__)), 'run_tests.rb')

sp_manual_timer = UI.start_timer(1, false) do
  UI.stop_timer(sp_manual_timer)
  SolidProcedural::Tests.manual_open_test
end
