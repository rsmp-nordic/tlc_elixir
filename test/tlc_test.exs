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
    if seconds > 0 do
      program = TLC.update_program(program)
      progress(program, seconds - 1)
    else
      # Extract relevant state values to a map with short keys for readability
      %{
        base: program.base_cycle_time,
        cycle: program.current_cycle_time,
        offset: program.offset,
        target: program.target_offset,
        states: extract_group_states_string(program),
        program: program  # Include the updated program for chaining
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

    # Set target offset to 3 initially
    program = TLC.set_target_offset(program, 3)

    # Initial state
    assert %{base: 0, cycle: 0, offset: 0, target: 3, states: "0A", program: program} = progress(program, 0)

    # Step by step progression showing the offset adjustment process
    assert %{base: 1, cycle: 3, offset: 2, target: 3, states: "A0", program: program} = progress(program, 1) # Hit skip point (0→2)
    assert %{base: 2, cycle: 4, offset: 2, target: 3, states: "A0", program: program} = progress(program, 1)
    assert %{base: 3, cycle: 5, offset: 2, target: 3, states: "A0", program: program} = progress(program, 1)
    assert %{base: 4, cycle: 0, offset: 2, target: 3, states: "0A", program: program} = progress(program, 1)
    assert %{base: 5, cycle: 3, offset: 4, target: 3, states: "A0", program: program} = progress(program, 1)  # Hit skip point again at cycle time 0 (2→4)
    assert %{base: 0, cycle: 3, offset: 3, target: 3, states: "A0", program: program} = progress(program, 1)  # Hit wait point (4→3)

    # Target is reached
    assert program.offset == program.target_offset
  end
end
