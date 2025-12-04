<objective>
Refactor the stage-based program structure to separate stage definitions from program definitions.

Currently `Tlc.Program.StageBased` contains both stages/transitions AND multiple internal programs.
This is confusing and makes program switching harder.

The goal is to:
1. Rename `Tlc.Program.StageBased` → `Tlc.Program.Stages` (contains stages, transitions, groups)
2. Create a new `Tlc.Program.StageBased` that references a `Tlc.Program.Stages` and represents a single program
3. Update `Tlc.Logic.StageBased` to work with the new structure
</objective>

<context>
Read these files to understand current structure:
- `lib/program/stage_based.ex` - Current combined struct with stages, transitions, AND programs
- `lib/logic/stage_based.ex` - Runtime logic that uses Program.StageBased
- `lib/tlc_elixir/server.ex` - Server that manages both fixed-time and stage-based programs
- `lib/tlc.ex` - TLC initialization

The current `Program.StageBased` has:
- `name`, `groups` - metadata
- `stages` - stage definitions (which groups are open)
- `transitions` - how to move between stages
- `programs` - map of internal programs with flows between stages

The internal `Program` struct inside StageBased has: `id`, `enter`, `leave`, `flows`
</context>

<requirements>
1. **Create `Tlc.Program.Stages`** (`lib/program/stages.ex`):
   - Move `groups`, `stages`, `transitions` from current StageBased
   - Add a `name` field for identification
   - Keep the nested structs: `Stage`, `Duration`, `Transition`, `TransitionStep`
   - Include helper functions like `get_stage_state/2`, `get_transition/4`, `transition_duration/1`
   - Include `from_config/1` parsing logic for stages/transitions

2. **Refactor `Tlc.Program.StageBased`** (`lib/program/stage_based.ex`):
   - Now represents a single program (not a container of programs)
   - Fields: `name`, `stages_ref` (reference to a Stages struct), `enter`, `leave`, `flows`
   - The `stages_ref` field holds a `Tlc.Program.Stages` struct
   - Move the `Program` and `Flow` structs logic here
   - Include `from_config/2` that takes a config and a Stages struct

3. **Update `Tlc.Logic.StageBased`** (`lib/logic/stage_based.ex`):
   - Update to work with new structure
   - Access stages/transitions via `program.stages_ref`
   - Remove `current_program_id` - the program IS the current program
   - Keep: `current_stage`, `current_transition`, `transition_elapsed`, `stage_elapsed`, etc.

4. **Update `Tlc.Server`** (`lib/tlc_elixir/server.ex`):
   - Update example programs in `init/1` to use new structure
   - Create a shared `Tlc.Program.Stages` and multiple `Tlc.Program.StageBased` referencing it
   - Update `detect_program_type/1` to handle new struct
   - Update `create_logic_for_program/3` for new structure

5. **Update tests** in `test/program/` to match new structure
</requirements>

<implementation>
Key structural change:

Before:
```elixir
%Tlc.Program.StageBased{
  name: "example",
  groups: [...],
  stages: %{...},
  transitions: %{...},
  programs: %{
    "normal" => %Program{enter: [...], leave: [...], flows: %{...}}
  }
}
```

After:
```elixir
# Shared stage definitions
stages = %Tlc.Program.Stages{
  name: "intersection_1",
  groups: [...],
  stages: %{...},
  transitions: %{...}
}

# Individual programs
%Tlc.Program.StageBased{
  name: "normal",
  stages_ref: stages,
  enter: ["main"],
  leave: ["main"],
  flows: %{...}
}

%Tlc.Program.StageBased{
  name: "rush_hour",
  stages_ref: stages,
  enter: ["main"],
  leave: ["side"],
  flows: %{...}
}
```

This allows multiple programs to share the same stage definitions while having different flow patterns.
</implementation>

<verification>
1. Run `mix compile` - should compile without errors
2. Run `mix test` - all tests should pass
3. Start the server and verify stage-based programs still work
4. Verify switching between internal stage-based programs works
</verification>

<success_criteria>
- `Tlc.Program.Stages` exists and contains stage/transition definitions
- `Tlc.Program.StageBased` represents a single program with a reference to Stages
- `Tlc.Logic.StageBased` works with the refactored structure
- Server initializes correctly with example programs
- Existing functionality is preserved
</success_criteria>
