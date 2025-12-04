<objective>
Update the TLC UI to have a common top section that works for all program types (fixed-time and stage-based).

Currently, program-specific information is scattered. We need a unified header that shows:
- Program selection (all programs in a list)
- Current program name and target program (if switching)
- Current time/position
- Mode indicator (running/halt/fault)
- Signal group lamps (current state visualization)

Information should not be duplicated - if it's in the common header, remove it from type-specific sections.
</objective>

<context>
Read these files:
- `lib/tlc_elixir_web/live/tlc_live.ex` - Main LiveView
- `lib/tlc_elixir_web/live/tlc_live.html.heex` - Template
- `lib/tlc_elixir_web/components/signal_components.ex` - Signal head visualization
- `lib/tlc_elixir_web/components/layout_components.ex` - Layout components
- `lib/tlc_elixir_web/components/editor_components.ex` - Editor components
- `lib/tlc_elixir_web/components/tlc_components.ex` - Component re-exports

Current UI structure:
- Signal heads section (shows lamp states)
- State section (shows mode, cycle time - fixed-time specific)
- Program editor container (has program controls, grid)
</context>

<requirements>
1. **Create `common_header/1` component** in `layout_components.ex`:
   - Program selector dropdown showing ALL programs (both types)
   - Current program name with type indicator (fixed/stage badge)
   - Target program indicator (if switching is pending)
   - Mode badge: "Running" (green), "Halt" (yellow), "Fault" (red)
   - Time display: cycle_time for fixed, stage_elapsed for stage-based
   - Signal group lamps (reuse `signal_heads_section` logic)

2. **Update `tlc_live.html.heex`**:
   - Add `<.common_header ... />` at the top
   - Remove duplicated information from type-specific sections
   - Keep type-specific details in their sections (cycle grid for fixed, stage diagram for stage)

3. **Update `state_section/1`** in `layout_components.ex`:
   - Remove items moved to common header
   - Keep only fixed-time specific details (cycle visualization, offset controls)
   - Or rename to `fixed_time_details/1`

4. **Create `stage_based_details/1`** component:
   - Show current stage name
   - Show available stages (clickable to request transition)
   - Show transition progress if in transition
   - Show stage duration countdown

5. **Update program switching in UI**:
   - Program dropdown should show both fixed-time and stage-based programs
   - Clicking a program sets it as target
   - Show "→ [target]" indicator when switch is pending
   - Clear pending switch with X button

6. **Signal group lamps**:
   - Works for both program types
   - Uses `current_states` from logic (both types have this field)
   - Groups come from program (both types have `groups` or can derive from `stages_ref.groups`)
</requirements>

<implementation>
Component structure:

```heex
<.common_header
  programs={@tlc.programs}
  current_program={@tlc.logic.program}
  target_program={@target_program}
  logic_type={@tlc.logic_type}
  mode={@tlc.logic.mode}
  time={get_display_time(@tlc)}
  groups={get_groups(@tlc)}
  current_states={@tlc.logic.current_states}
/>

<!-- Type-specific sections -->
<%= if @tlc.logic_type == :fixed_time do %>
  <.fixed_time_details logic={@tlc.logic} ... />
<% else %>
  <.stage_based_details logic={@tlc.logic} ... />
<% end %>
```

Helper functions needed in LiveView:
- `get_display_time/1` - returns appropriate time for logic type
- `get_groups/1` - returns groups list for either program type
</implementation>

<verification>
1. Start the application with `mix phx.server`
2. Verify common header displays correctly
3. Test program switching via dropdown
4. Verify signal lamps work for both program types
5. Verify no duplicate information shown
6. Test mode changes (halt, fault) update the badge
</verification>

<success_criteria>
- Common header shows program selector, current/target program, mode, time, signal lamps
- Works correctly for both fixed-time and stage-based programs
- No duplicate information between header and type-specific sections
- Program switching via dropdown works for cross-type switches
- Signal lamps display correctly for both program types
</success_criteria>
