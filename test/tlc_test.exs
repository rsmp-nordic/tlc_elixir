defmodule TLCTest do
  use ExUnit.Case

  # Helper function to create a program from inline YAML
  defp program_from_yaml(yaml_string) do
    {:ok, yaml} = YamlElixir.read_from_string(yaml_string)
    program = %TLC.TrafficProgram{
      length: yaml["length"],
      offset: yaml["offset"] || 0,
      target_offset: yaml["offset"] || 0,
      groups: yaml["groups"],
      states: yaml["states"],
      skips: yaml["skips"] || %{},
      waits: yaml["waits"] || %{},
      switch: yaml["switch"] || [],
      base_cycle_time: 0,
      current_cycle_time: 0
    }

    # Pre-calculate states
    precalculated_states = TLC.precalculate_states(program)
    %{program | precalculated_states: precalculated_states}
  end

  # Helper to advance the program by n seconds and return a map with the relevant state
  defp progress(program, seconds) do
    # Apply skip points to the initial state if needed
    if seconds == 0 do
      program = TLC.apply_skip_points(program)

      # Extract relevant state values
      %{
        base: program.base_cycle_time,
        cycle: program.current_cycle_time,
        offset: program.offset,
        target: program.target_offset,
        states: extract_group_states_string(program),
        program: program
      }
    else
      # For subsequent updates, advance the program by specified number of seconds
      updated_program = Enum.reduce(1..seconds, program, fn _, prog ->
        TLC.update_program(prog)
      end)

      # Extract relevant state values
      %{
        base: updated_program.base_cycle_time,
        cycle: updated_program.current_cycle_time,
        offset: updated_program.offset,
        target: updated_program.target_offset,
        states: extract_group_states_string(updated_program),
        program: updated_program
      }
    end
  end

  # Helper to extract the current group states as a simple string
  defp extract_group_states_string(program) do
    TLC.get_current_states_string(program)
  end

  test "offset shift with skip and wait points" do
    yaml = """
    length: 6
    offset: 0
    groups: ["a", "b"]
    states:
      0: "AA"
      3: "BB"
    skips:
      "0": 2  # at cycle time 0, skip forward 2 seconds
    waits:
      "3": 2  # at cycle time 3, wait up to 2 seconds
    """

    program = program_from_yaml(yaml)
    program = TLC.set_target_offset(program, 3) # Set target offset to 3 before any progression

    result = progress(program, 0);        assert %{base: 0, offset: 2, cycle: 0, target: 3, states: "AA"} = result  # Skip 0 -> 2
    result = progress(result.program, 1); assert %{base: 1, offset: 2, cycle: 3, target: 3, states: "BB"} = result
    result = progress(result.program, 1); assert %{base: 2, offset: 2, cycle: 4, target: 3, states: "BB"} = result
    result = progress(result.program, 1); assert %{base: 3, offset: 2, cycle: 5, target: 3, states: "BB"} = result
    result = progress(result.program, 1); assert %{base: 4, offset: 4, cycle: 2, target: 3, states: "AA"} = result  # Skip 2 -> 4
    result = progress(result.program, 1); assert %{base: 5, offset: 4, cycle: 3, target: 3, states: "BB"} = result  # Wait point reached
    result = progress(result.program, 1); assert %{base: 0, offset: 3, cycle: 3, target: 3, states: "BB"} = result  # Wait 4 -> 3, target offset reached

  end

  test "base and cycle wrap around" do
    yaml = """
    length: 6
    offset: 0
    groups: ["a", "b"]
    states:
      0: "AA"
      3: "BB"
    skips:
      "0": 2  # at cycle time 0, skip forward 2 seconds
    waits:
      "3": 2  # at cycle time 3, wait up to 2 seconds
    """

    program = program_from_yaml(yaml)

    result = progress(program, 0);        assert %{base: 0, offset: 0, cycle: 0, target: 0, states: "AA"} = result
    result = progress(result.program, 1); assert %{base: 1, offset: 0, cycle: 1, target: 0, states: "AA"} = result
    result = progress(result.program, 1); assert %{base: 2, offset: 0, cycle: 2, target: 0, states: "AA"} = result
    result = progress(result.program, 1); assert %{base: 3, offset: 0, cycle: 3, target: 0, states: "BB"} = result
    result = progress(result.program, 1); assert %{base: 4, offset: 0, cycle: 4, target: 0, states: "BB"} = result
    result = progress(result.program, 1); assert %{base: 5, offset: 0, cycle: 5, target: 0, states: "BB"} = result
    result = progress(result.program, 1); assert %{base: 0, offset: 0, cycle: 0, target: 0, states: "AA"} = result
    result = progress(result.program, 1); assert %{base: 1, offset: 0, cycle: 1, target: 0, states: "AA"} = result
  end

end
