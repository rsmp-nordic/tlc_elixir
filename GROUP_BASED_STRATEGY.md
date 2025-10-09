# Group-Based Control Strategy

This document describes the group-based control strategy implementation in the TLC Elixir application.

## Overview

Group-based control is an alternative strategy to fixed-time programs. Instead of defining explicit state sequences and timing, group-based programs use constraints:

- **Timing constraints**: Min/max green times for each signal group
- **Conflict matrix**: Which signal groups cannot be green simultaneously
- **Dynamic behavior**: The controller determines when to switch groups based on constraints

This is inspired by the constraint-based traffic light programming approach described in:
https://raw.githubusercontent.com/rsmp-nordic/tlc_programming/895d25119b40fa4f14df3e810ae397391aecd9b1/group_based.md

## Implementation

### Core Modules

#### `Tlc.Program.GroupBased`
Located in `lib/program/group_based.ex`

Defines the structure and validation for group-based programs:
- **Fields**: `name`, `strategy`, `groups`, `timing`, `conflicts`, `switch`, `halt`
- **Validation**: Ensures all groups have timing, conflicts reference valid groups
- **Helper functions**: Check conflicts between groups, get timing constraints

```elixir
program = %Tlc.Program.GroupBased{
  name: "adaptive",
  strategy: :group_based,
  groups: ["sg1", "sg2"],
  timing: %{
    "sg1" => %{min_green: 10, max_green: 60},
    "sg2" => %{min_green: 8, max_green: 45}
  },
  conflicts: [
    ["sg1", "sg2"]  # sg1 and sg2 cannot be green together
  ]
}
```

#### `Tlc.Logic.GroupBased`
Located in `lib/logic/group_based.ex`

Implements the runtime logic for group-based programs:
- **State tracking**: Which group is currently green and for how long
- **Constraint enforcement**: Respects min/max green times and conflicts
- **Simple strategy**: Round-robin selection of groups (can be enhanced)

The logic:
1. Starts with all groups at red
2. Selects a group to turn green (currently round-robin)
3. Keeps the group green for at least `min_green` seconds
4. Switches to next group at `min_green` time (basic implementation)
5. Ensures conflicting groups are kept red

#### `Tlc.Logic` Integration
Updated `lib/tlc_logic.ex` to support both strategies:

- **Dispatch in `new/2`**: Detects program type and creates appropriate logic
- **Dispatch in `tick/2`**: Routes to group-based logic if applicable
- **Guard clauses**: Operations not supported by group-based (e.g., offset adjustment) are no-ops

### UI Updates

#### Program Display
Updated `lib/tlc_elixir_web/components/editor_components.ex`:

- **Program buttons**: Show "group-based" badge for group-based programs
- **Alternative view**: Instead of grid, shows:
  - List of signal groups
  - Timing constraints (min/max green)
  - Conflict relationships
  - Explanatory text about constraint-based control

The UI automatically adapts based on the program's `strategy` field.

### Server Integration

Added example group-based program to `lib/tlc_elixir/server.ex`:
- Program named "adaptive" with 2 groups
- Demonstrates timing constraints and conflicts
- Available in the program selector

## Simplified Implementation

This is a **basic implementation** focusing on core concepts:

### What's Included
✓ Constraint definition (timing, conflicts)
✓ Constraint validation
✓ Basic state transitions respecting constraints
✓ UI display of constraints
✓ Integration with existing fixed-time logic

### What's Simplified
- **Selection strategy**: Simple round-robin (could be demand-based, optimized, etc.)
- **Transitions**: Direct R→G→R (no yellow/all-red phases)
- **No sensors**: No detector input or demand management
- **No coordination**: No inter-intersection coordination
- **No optimization**: No complex objective function

### Future Enhancements

To expand this implementation:

1. **Proper transitions**: Add yellow and all-red times from regional config
2. **Sensor input**: Accept detector data to create demand for groups
3. **Smart selection**: Choose next group based on demand, wait time, optimization
4. **Intergreen times**: Enforce minimum clearance between conflicting groups
5. **Coordination**: Support offset relationships with other intersections
6. **Multiple strategies**: Different algorithms for group selection (FIFO, priority-based, etc.)

## Testing

Tests are organized into three files:

- `test/program_group_based_test.exs`: Tests for program structure and validation
- `test/logic_group_based_test.exs`: Tests for runtime logic behavior
- `test/tlc_integration_test.exs`: Integration tests for both program types

Run tests with:
```bash
mix test test/program_group_based_test.exs
mix test test/logic_group_based_test.exs
mix test test/tlc_integration_test.exs
```

## Usage Example

```elixir
# Create a group-based program
program = %Tlc.Program.GroupBased{
  name: "my_adaptive_program",
  groups: ["north_south", "east_west", "pedestrian"],
  timing: %{
    "north_south" => %{min_green: 15, max_green: 60},
    "east_west" => %{min_green: 12, max_green: 50},
    "pedestrian" => %{min_green: 10, max_green: 20}
  },
  conflicts: [
    ["north_south", "east_west"],    # perpendicular flows
    ["north_south", "pedestrian"],   # ped crosses north_south
    ["east_west", "pedestrian"]      # ped crosses east_west
  ]
}

# Validate the program
{:ok, validated_program} = Tlc.Program.GroupBased.validate(program)

# Create logic instance
logic = Tlc.Logic.new(validated_program)

# Run the controller
logic = Tlc.Logic.tick(logic, current_time)
states = logic.current_states  # "GRR", "RGR", etc.
```

## Architecture Benefits

The modular design allows:
- **Strategy independence**: Fixed-time and group-based logic are separate
- **Easy extension**: New strategies can be added similarly
- **Backward compatibility**: Existing fixed-time programs work unchanged
- **Type safety**: Pattern matching on program type ensures correct handling
- **UI flexibility**: Different views for different program types

## References

- [Group-based programming specification](https://raw.githubusercontent.com/rsmp-nordic/tlc_programming/895d25119b40fa4f14df3e810ae397391aecd9b1/group_based.md)
- Original fixed-time implementation in `lib/program.ex` and `lib/tlc_logic.ex`
