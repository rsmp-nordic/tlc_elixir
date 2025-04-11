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
    # Find the last defined state up to the current cycle time
    current_time = program.current_cycle_time

    # Find the defined cycle time that is active now
    active_state_time = program.precalculated_states
      |> Map.keys()
      |> Enum.filter(fn t -> t <= current_time end)
      |> Enum.max(fn -> 0 end)

    # Get the states for that time
    states = Map.get(program.precalculated_states, active_state_time, %{})
    Enum.map(program.groups, fn group -> Map.get(states, group, "-") end)
    |> Enum.join("")
  end

  test "comprehensive offset adjustment with skip and wait points" do
    yaml = """
    length: 6
    offset: 0
    groups: ["a", "b"]
    states:
      0: "0A"
      3: "A0"
    skips:
      "0": 2  # at cycle time 0, skip forward 2 seconds
    waits:
      "3": 2  # at cycle time 3, wait up to 2 seconds
    """

    program = program_from_yaml(yaml)

    # Set target offset to 3 before any progression
    program = TLC.set_target_offset(program, 3)

    # Initial state - skip point at 0 should be applied immediately
    result = progress(program, 0)
    assert %{base: 0, cycle: 0, offset: 2, target: 3, states: "0A"} = result

    # Step by step progression showing the offset adjustment process
    result = progress(result.program, 1)
    assert %{base: 1, cycle: 3, offset: 2, target: 3, states: "A0"} = result

    result = progress(result.program, 1)
    assert %{base: 2, cycle: 4, offset: 2, target: 3, states: "A0"} = result

    result = progress(result.program, 1)
    assert %{base: 3, cycle: 5, offset: 2, target: 3, states: "A0"} = result

    result = progress(result.program, 1)
    assert %{base: 4, cycle: 0, offset: 4, target: 3, states: "0A"} = result  # Skip point should be applied here (cycle 0)

    result = progress(result.program, 1)
    assert %{base: 5, cycle: 5, offset: 4, target: 3, states: "A0"} = result

    result = progress(result.program, 1)
    assert %{base: 6, cycle: 0, offset: 4, target: 3, states: "0A"} = result  # Skip point NOT applied - offset already above target

    result = progress(result.program, 1)
    assert %{base: 7, cycle: 1, offset: 4, target: 3, states: "0A"} = result

    result = progress(result.program, 1)
    assert %{base: 8, cycle: 2, offset: 4, target: 3, states: "0A"} = result

    result = progress(result.program, 1)
    assert %{base: 9, cycle: 3, offset: 3, target: 3, states: "A0"} = result  # Wait point at cycle 3 reduces offset to target

  end
end
