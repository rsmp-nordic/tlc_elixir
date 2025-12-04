<objective>
Implement safe switching between fixed-time and stage-based programs.

A traffic light controller can never switch immediately between programs as this might cause invalid state changes (e.g., going directly from red to green without yellow). Both program types define mechanisms for safe switching:
- Fixed-time: switch points (specific cycle positions)
- Stage-based: enter/leave stages

This prompt implements the logic for cross-type switching that respects these safety mechanisms.
</objective>

<context>
Read these files:
- `lib/tlc_elixir/server.ex` - Server with `maybe_switch_to_target_program/1`
- `lib/logic/fixed_time.ex` - Has `check_switch/1` at switch point
- `lib/logic/stage_based.ex` - Has stage transitions with enter/leave stages
- `lib/program/stage_based.ex` - Has `enter` and `leave` fields (after prompt 009)
- `lib/program/stages.ex` - Has stage definitions (after prompt 009)

Current switching in server:
- `target_program` stores pending cross-type switch
- `at_switch_point?` check exists but needs proper implementation
</context>

<requirements>
1. **Add `at_switch_point?/1` to `Tlc.Logic.FixedTime`**:
   - Returns true when `cycle_time == program.switch`
   - This is where fixed-time programs can safely switch out

2. **Add `at_switch_point?/1` to `Tlc.Logic.StageBased`**:
   - Returns true when in a "leave" stage and not in a transition
   - This is where stage-based programs can safely switch out

3. **Update `Tlc.Server.maybe_switch_to_target_program/1`**:
   - Check `at_switch_point?` for current logic type
   - When switching FROM fixed-time TO stage-based:
     - Wait for fixed-time switch point
     - Start stage-based at its first "enter" stage
   - When switching FROM stage-based TO fixed-time:
     - Wait for stage-based leave stage (not in transition)
     - Start fixed-time at its switch point

4. **Add `start_at_enter_stage/1` to `Tlc.Logic.StageBased`**:
   - Initializes the logic at the first enter stage of the program
   - Sets initial states correctly

5. **Update `create_logic_for_program/3` in server**:
   - For stage-based: use `start_at_enter_stage` when switching from another program
   - For fixed-time: sync to switch point when switching from another program

6. **Handle edge cases**:
   - What if stage-based has no leave stages? (use any stage)
   - What if there's no valid enter stage? (use first stage)
</requirements>

<implementation>
Switching flow:

```
Fixed-Time → Stage-Based:
1. User requests switch to stage-based program
2. Server stores target_program
3. Each tick, check if at fixed-time switch point
4. When at switch point:
   - Create new StageBased logic
   - Start at first enter stage
   - Clear target_program

Stage-Based → Fixed-Time:
1. User requests switch to fixed-time program
2. Server stores target_program
3. Each tick, check if in leave stage AND not transitioning
4. When at leave stage:
   - Create new FixedTime logic
   - Sync to switch point
   - Clear target_program
```
</implementation>

<verification>
1. Run `mix test` - all tests pass
2. Manual test in UI:
   - Switch from fixed-time to stage-based - should wait for switch point
   - Switch from stage-based to fixed-time - should wait for leave stage
   - Verify no invalid signal transitions occur (check safety module)
</verification>

<success_criteria>
- `at_switch_point?/1` implemented for both logic types
- Cross-type switching waits for appropriate safe moment
- No invalid signal transitions during switches
- Both directions (fixed→stage, stage→fixed) work correctly
</success_criteria>
