#!/usr/bin/env elixir

# Demo script showing phase-based control strategy working alongside fixed-time strategy

Code.compile_file("lib/tlc/phase/phase.ex")
Code.compile_file("lib/tlc/phase/program.ex")
Code.compile_file("lib/tlc/phase/logic.ex")
Code.compile_file("lib/tlc/fixed_time/program.ex")
Code.compile_file("lib/tlc/fixed_time/logic.ex")
Code.compile_file("lib/program.ex")
Code.compile_file("lib/tlc_logic.ex")
Code.compile_file("lib/tlc.ex")

IO.puts """
=== RSMP TLC Elixir - Phase-Based Control Strategy Demo ===

This demo shows the new phase-based control strategy working alongside 
the existing fixed-time strategy.
"""

# Create example programs
fixed_time_program = Tlc.Program.fixed_time_example()
phase_program = Tlc.Program.phase_example()

IO.puts "\n=== Program Comparison ==="
IO.puts "Fixed-time program: #{fixed_time_program.name}"
IO.puts "  - Type: #{Tlc.Program.program_type(fixed_time_program)}"
IO.puts "  - Length: #{fixed_time_program.length} seconds"
IO.puts "  - Groups: #{Enum.join(fixed_time_program.groups, ", ")}"
IO.puts "  - States defined at: #{Enum.join(Map.keys(fixed_time_program.states) |> Enum.sort(), ", ")}"

IO.puts "\nPhase program: #{phase_program.name}"
IO.puts "  - Type: #{Tlc.Program.program_type(phase_program)}"
IO.puts "  - Cycle: #{phase_program.cycle} seconds"
IO.puts "  - Groups: #{Enum.join(phase_program.groups, ", ")}"
IO.puts "  - Phases: #{Enum.join(phase_program.order, ", ")}"
IO.puts "  - Total phase duration: #{Tlc.Phase.Program.total_phase_duration(phase_program)} seconds"
IO.puts "  - Interphase time: #{Tlc.Phase.Program.interphase_time(phase_program)} seconds"

# Show phase details
IO.puts "\n=== Phase Details ==="
for phase_name <- phase_program.order do
  phase = Map.get(phase_program.phases, phase_name)
  IO.puts "#{phase.name}: #{Enum.join(phase.groups, ", ")} open for #{phase.duration}s"
  if phase.min, do: IO.puts "  - Min duration: #{phase.min}s"
  if phase.max, do: IO.puts "  - Max duration: #{phase.max}s"
end

# Show state resolution over time
IO.puts "\n=== State Resolution Comparison ==="
IO.puts "Time | Fixed-Time | Phase-Based"
IO.puts "-----|------------|------------"
for time <- 0..9 do
  fixed_state = Tlc.Program.resolve_state(fixed_time_program, time)
  phase_state = Tlc.Program.resolve_state(phase_program, time)
  IO.puts "#{String.pad_leading(to_string(time), 4)} | #{String.pad_trailing(fixed_state, 10)} | #{phase_state}"
end

# Show phase offset adjustment calculation
IO.puts "\n=== Phase Offset Adjustment Demo ==="
IO.puts "If we need to move the phase program forward by 6 seconds:"
adjustments = Tlc.Phase.Program.calculate_proportional_adjustments(phase_program, 6)
for {phase_name, adjustment} <- adjustments do
  phase = Map.get(phase_program.phases, phase_name)
  new_duration = phase.duration + adjustment
  IO.puts "  #{phase_name}: #{phase.duration}s → #{new_duration}s (#{if adjustment >= 0, do: "+", else: ""}#{adjustment}s)"
end

IO.puts "\nIf we need to move the phase program backward by 4 seconds:"
adjustments = Tlc.Phase.Program.calculate_proportional_adjustments(phase_program, -4)
for {phase_name, adjustment} <- adjustments do
  phase = Map.get(phase_program.phases, phase_name)
  new_duration = phase.duration + adjustment
  IO.puts "  #{phase_name}: #{phase.duration}s → #{new_duration}s (#{if adjustment >= 0, do: "+", else: ""}#{adjustment}s)"
end

# Test logic creation
IO.puts "\n=== Logic Creation Test ==="
fixed_logic = Tlc.Logic.new(fixed_time_program)
phase_logic = Tlc.Logic.new(phase_program)

IO.puts "Fixed-time logic created: #{is_struct(fixed_logic, Tlc.FixedTime.Logic)}"
IO.puts "Phase logic created: #{is_struct(phase_logic, Tlc.Phase.Logic)}"

# Simulate one tick for each
fixed_logic = Tlc.Logic.tick(fixed_logic, 0)
phase_logic = Tlc.Logic.tick(phase_logic, 0)

IO.puts "After first tick:"
IO.puts "  Fixed-time states: #{fixed_logic.current_states}"
IO.puts "  Phase states: #{phase_logic.current_states}"

IO.puts "\n=== Demo Complete ==="
IO.puts "Both fixed-time and phase-based strategies are working correctly!"
IO.puts "The unified interface allows seamless switching between program types."