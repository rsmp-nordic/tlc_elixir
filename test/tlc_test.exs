defmodule TLCTest do
  use ExUnit.Case

  # Helper function to create a program from inline YAML
  defp program_from_yaml(yaml_string) do
    {:ok, yaml} = YamlElixir.read_from_string(yaml_string)
    %TLC.TrafficProgram{
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
  end

  # Helper to start the program by and return a map with the relevant state
  defp start(program) do
    TLC.apply_skip_points(program)
    |> to_map
  end

  # Helper to return a map with the relevant program state
  defp to_map(program) do
    # Initialize the program state
    %{
      base: program.base_cycle_time,
      cycle: program.current_cycle_time,
      offset: program.offset,
      target: program.target_offset,
      states: extract_group_states_string(program),
      program: program
    }
  end

  # Helper to advance the program by n seconds and return a map with the relevant state
  defp progress(program) do
    TLC.update_program(program)
    |> to_map
  end

  # Helper to extract the current group states as a simple string
  defp extract_group_states_string(program) do
    # Use find_state_for_cycle_time directly
    TLC.find_state_for_cycle_time(program.states, program.current_cycle_time)
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

    result = start(program);           assert %{base: 0, offset: 2, cycle: 0, target: 3, states: "AA"} = result  # Skip 0 -> 2
    result = progress(result.program); assert %{base: 1, offset: 2, cycle: 3, target: 3, states: "BB"} = result
    result = progress(result.program); assert %{base: 2, offset: 2, cycle: 4, target: 3, states: "BB"} = result
    result = progress(result.program); assert %{base: 3, offset: 2, cycle: 5, target: 3, states: "BB"} = result
    result = progress(result.program); assert %{base: 4, offset: 4, cycle: 2, target: 3, states: "AA"} = result  # Skip 2 -> 4
    result = progress(result.program); assert %{base: 5, offset: 4, cycle: 3, target: 3, states: "BB"} = result  # Wait point reached
    result = progress(result.program); assert %{base: 0, offset: 3, cycle: 3, target: 3, states: "BB"} = result  # Wait 4 -> 3, target offset reached

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

    result = start(program);           assert %{base: 0, offset: 0, cycle: 0, target: 0, states: "AA"} = result
    result = progress(result.program); assert %{base: 1, offset: 0, cycle: 1, target: 0, states: "AA"} = result
    result = progress(result.program); assert %{base: 2, offset: 0, cycle: 2, target: 0, states: "AA"} = result
    result = progress(result.program); assert %{base: 3, offset: 0, cycle: 3, target: 0, states: "BB"} = result
    result = progress(result.program); assert %{base: 4, offset: 0, cycle: 4, target: 0, states: "BB"} = result
    result = progress(result.program); assert %{base: 5, offset: 0, cycle: 5, target: 0, states: "BB"} = result
    result = progress(result.program); assert %{base: 0, offset: 0, cycle: 0, target: 0, states: "AA"} = result
    result = progress(result.program); assert %{base: 1, offset: 0, cycle: 1, target: 0, states: "AA"} = result
  end

  test "skip duration wrap around" do
    yaml = """
    length: 6
    offset: 0
    groups: ["a", "b"]
    states:
      0: "AA"
      3: "BB"
    skips:
      "5": 2  # at cycle time 5, skip forward 2 seconds
    waits:
      "2": 2  # at cycle time 2, wait up to 2 seconds
    """

    program = program_from_yaml(yaml)
    program = TLC.set_target_offset(program, 3) # Set target offset to 3 before any progression

    result = start(program);           assert %{base: 0, offset: 0, cycle: 0, target: 3, states: "AA"} = result
    result = progress(result.program); assert %{base: 1, offset: 0, cycle: 1, target: 3, states: "AA"} = result
    result = progress(result.program); assert %{base: 2, offset: 0, cycle: 2, target: 3, states: "AA"} = result
    result = progress(result.program); assert %{base: 3, offset: 0, cycle: 3, target: 3, states: "BB"} = result
    result = progress(result.program); assert %{base: 4, offset: 0, cycle: 4, target: 3, states: "BB"} = result
    result = progress(result.program); assert %{base: 5, offset: 2, cycle: 1, target: 3, states: "AA"} = result # skip 5 -> 2
  end

  test "wait for multiple cycles" do
    yaml = """
    length: 6
    offset: 0
    groups: ["a", "b"]
    states:
      0: "AA"
      3: "BB"
    skips:
    waits:
      "4": 3  # at cycle time 4, wait up to 3 seconds
    """

    program = program_from_yaml(yaml)
    program = TLC.set_target_offset(program, 1) # Set target offset to 1 before any progression

    result = start(program);           assert %{base: 0, offset: 0, cycle: 0, target: 1, states: "AA"} = result
    result = progress(result.program); assert %{base: 1, offset: 0, cycle: 1, target: 1, states: "AA"} = result
    result = progress(result.program); assert %{base: 2, offset: 0, cycle: 2, target: 1, states: "AA"} = result
    result = progress(result.program); assert %{base: 3, offset: 0, cycle: 3, target: 1, states: "BB"} = result
    result = progress(result.program); assert %{base: 4, offset: 0, cycle: 4, target: 1, states: "BB"} = result # wait point reached
    result = progress(result.program); assert %{base: 5, offset: 5, cycle: 4, target: 1, states: "BB"} = result # wait 0 -> 5
    result = progress(result.program); assert %{base: 0, offset: 4, cycle: 4, target: 1, states: "BB"} = result # skip 5 -> 4
    result = progress(result.program); assert %{base: 1, offset: 3, cycle: 4, target: 1, states: "BB"} = result # skip 4 -> 3
    result = progress(result.program); assert %{base: 2, offset: 3, cycle: 5, target: 1, states: "BB"} = result
    result = progress(result.program); assert %{base: 3, offset: 3, cycle: 0, target: 1, states: "AA"} = result
    result = progress(result.program); assert %{base: 3, offset: 3, cycle: 0, target: 1, states: "AA"} = result
    result = progress(result.program); assert %{base: 3, offset: 3, cycle: 0, target: 1, states: "AA"} = result
    result = progress(result.program); assert %{base: 3, offset: 3, cycle: 0, target: 1, states: "BB"} = result
    result = progress(result.program); assert %{base: 4, offset: 3, cycle: 4, target: 1, states: "BB"} = result # wait point reached
    result = progress(result.program); assert %{base: 5, offset: 2, cycle: 4, target: 1, states: "BB"} = result # wait 3 -> 2
    result = progress(result.program); assert %{base: 0, offset: 1, cycle: 4, target: 1, states: "BB"} = result # skip 2 -> 1, target offset reached
    result = progress(result.program); assert %{base: 1, offset: 1, cycle: 5, target: 1, states: "BB"} = result
  end

end
