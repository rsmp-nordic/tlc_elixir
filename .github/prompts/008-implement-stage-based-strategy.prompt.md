# Implement Stage-Based Strategy Support

## Objective
Add support for stage-based traffic light control strategy as defined in the RSMP Nordic specification.

## Prerequisites
- Prompt 007 must be completed first (modules refactored to namespaced versions)

## Context
Stage-based control is an alternative to fixed-time control where:
- **Stages** define which signal groups can have green simultaneously
- **Interstages** define transitions between stages with specific signal group states
- Signal groups are explicitly assigned to stages in configuration

## Specification Reference
Full specification: https://github.com/rsmp-nordic/tlc_programming/blob/main/stage-based.md

### Key concepts from spec:

**Stages**: A stage defines which signal groups can have green at the same time.
```yaml
stages:
  - id: A
    groups: [1, 2]    # Signal groups that are green in this stage
  - id: B  
    groups: [3, 4]
```

**Interstages**: Define transitions between stages with explicit states for each signal group.
```yaml
interstages:
  - from: A
    to: B
    states:
      - { groups: [1, 2], state: red }
      - { groups: [3, 4], state: red-yellow }
```

## Requirements

### 1. Create Program.StageBased module
Create `lib/program/stage_based.ex` with:

```elixir
defmodule Program.StageBased do
  @moduledoc """
  Static configuration for stage-based signal programs.
  """
  
  defstruct [
    :id,
    :signal_groups,    # List of signal group definitions
    :stages,           # List of stage definitions  
    :interstages,      # List of interstage definitions
    :timings           # Timing parameters
  ]
  
  # Define nested structs for:
  # - SignalGroup (id, type, min_green, min_red, etc.)
  # - Stage (id, groups)
  # - Interstage (from, to, states)
  # - InterstageState (groups, state, duration)
end
```

### 2. Create Logic.StageBased module
Create `lib/logic/stage_based.ex` with:

```elixir
defmodule Logic.StageBased do
  @moduledoc """
  Runtime execution logic for stage-based programs.
  Handles stage switching and interstage transitions.
  """
  
  defstruct [
    :program,          # Reference to Program.StageBased
    :current_stage,    # Current active stage ID
    :current_interstage, # Current interstage (if transitioning)
    :group_states,     # Current state of each signal group
    :timers            # Active timers
  ]
  
  # Implement:
  # - new/1 - Create new logic instance from program
  # - tick/1 - Advance time by one tick
  # - request_stage/2 - Request transition to a stage
  # - get_group_state/2 - Get current state of a signal group
end
```

### 3. Implement basic stage switching
The minimal MVP should support:
- Starting in a configured initial stage
- Requesting a stage change
- Executing the pre-defined interstage transition
- Arriving at the new stage

### 4. Add tests
Create `test/program/stage_based_test.exs` and `test/logic/stage_based_test.exs` with tests for:
- Creating a program from configuration
- Stage transitions through interstages
- Signal group state changes during transitions

## Implementation approach

### Signal group states
Use the same state representations as the existing fixed-time implementation where applicable.

### Interstage execution
When transitioning from stage A to stage B:
1. Look up interstage definition for A→B
2. Apply each state change in sequence based on timing
3. When interstage completes, activate stage B

### Configuration-based
All stages, interstages, and signal group assignments come from configuration (not auto-calculated).

## Files to create
- `lib/program/stage_based.ex`
- `lib/logic/stage_based.ex`
- `test/program/stage_based_test.exs`
- `test/logic/stage_based_test.exs`

## Files to reference
- `lib/program/fixed_time.ex` - For patterns and conventions
- `lib/logic/fixed_time.ex` - For patterns and conventions
- Specification at https://github.com/rsmp-nordic/tlc_programming/blob/main/stage-based.md

## Success criteria
- [ ] `Program.StageBased` module parses stage-based configuration
- [ ] `Logic.StageBased` module executes stage transitions
- [ ] Interstages are executed with correct signal group states
- [ ] All new tests pass
- [ ] `mix compile` succeeds
- [ ] `mix test` passes (including new tests)

## Notes
- This is a minimal MVP - no demand handling, green extensions, or coordination
- Focus on clean, well-structured code that can be extended later
- Follow existing patterns from the fixed-time implementation
