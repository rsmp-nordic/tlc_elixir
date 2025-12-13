# Stage-Based Program Editor Specification

This document describes the features, UI, behaviors, and validation rules for adding a stage-based program editor to the TLC app.

It references the existing application patterns (fixed-time program editor), and the RSMP TLC stage-based programming draft: https://raw.githubusercontent.com/rsmp-nordic/tlc_programming/refs/heads/main/stage-based.md

## Goal
Add a first-class editor for `Tlc.Program.StageBased` programs. The editor should allow users to: create, update, view and validate StageBased programs, including selection of `stages_ref`, enter/leave stage lists and flows between stages (including transition variants).

This document focuses exclusively on the editor UX/behavior and validation, not implementation details.

---

## Definitions and Data Model

- Stage-based Program (`Tlc.Program.StageBased`): a program definition containing the following fields used by the app:
  - `name` (string) - program name
  - `stages_ref` (Tlc.Program.Stages struct reference) - references the shared stages definition with groups, stages, and transition variants
  - `enter` (list of stage IDs) - stage IDs that the program may start in
  - `leave` (list of stage IDs) - stage IDs that represent leave points
  - `flows` (map) - map from source stage id to a list of flows (Flow struct with `to` and `transition`)

- Stages (`Tlc.Program.Stages`): a reusable structure that defines groups, stages (open lists, durations), and transitions (named variants with explicit sequences).

Note: Stage definitions and transitions are maintained separately by a `Stages` editor (not within the scope of this program editor), but the program editor should provide a light-weight view and a link to open the Stages editor.

---

## High-level UI structure

Reuse the fixed-time editor layout and patterns where appropriate. Specifically:
- Program area: reuse `program_buttons_list`, `program_action_buttons`, `program_edit_form` for program selection, name, and save/cancel flow.
- Editor container: when editing a stage-based program, replace the `program_grid` display with stage-based visualizations:
  - **Stage Table**: shows all `stages` in the selected `stages_ref` (id, open groups, durations).
  - **Flows Table**: shows flows for each `from` stage (to stage, transition variant, order). Supports add / edit / delete / reorder.
  - **Enter / Leave**: UI to set one or more `enter` and `leave` stage IDs from stage list.
  - **Transition Details**: when selecting a flow, show the transition sequence (states and durations) from `stages_ref.transitions` and transitions summary.

Additionally, keep the existing JSON editor area (`program_definition_section`) for advanced users — changes in the UI and JSON panel should remain synchronized where sensible.

---

## Editor Components

### Top controls (reused)
- Program selector: list of programs (same as fixed-time) for switching program.
- Edit button: `start_editing`, toggles editor to `editing` mode.
- Save / Cancel / Apply: use existing `save_program`, `cancel_editing`, and `apply_program_definition` events.

### Stage selection / stages_ref picker
- `stages_ref`: a dropdown or small list that displays available Stages definitions found in the application (example: `example_stages`, `example_stages_six`).
- Show a `view stages` or `edit stages` link which navigates to the `Stages` editor (if implemented).
- When `stages_ref` is changed, do an immediate validation of the flows and update UI.

### Stage Table
- Columns: `Stage ID | Open Groups | Duration (default) | Min | Max`.
- Each row corresponds to one stage from `stages_ref.stages`.
- Durations fields should be editable (if stage durations are allowed to be overridden per program — otherwise read-only). If not allowed, show as read-only with small hint text.
- Clicking a stage should highlight flows that originate from or target that stage in the Flows Table.
- Mark unused stages (i.e., not referenced by `flows` or `enter`/`leave`) with a subtle color/warning.

### Flows Table (Primary program configuration area)
- Layout: Group flows by `from` stage - the UI lists each `from` stage as a section with their flows beneath.
- Each flow row includes:
  - To stage: dropdown selecting the destination stage (or special `leave` target).
  - Transition Variant: dropdown populated from `stages_ref.transitions[{from, to}]` with the `default` variant preselected.
  - Reorder/hamburger handle: allow re-ordering multiple flows from the same `from` stage (if order matters for some logic or presentation).
  - Remove button (trash icon) to delete the flow.
- Add Flow button: 'Add flow' button under each `from` stage to create a new flow row.
- Flow creation / editing: inline editing is preferred; a flow row should default new values sensibly (`to` default is the first stage not equal to `from`, `transition` default is `default` if available).

### Enter / Leave fields
- Multi-select lists for `enter` and `leave` stage IDs using `stages_ref.stages`.
- When the user selects `leave`, offer a checkbox or toggle to let the UI set flows to `leave` automatically (i.e., in the `flows` map use `to: "leave"`) or manage `leave` list directly.
- Editing `enter`/`leave` must re-run validation.

### Transition Details / Preview
- When a flow row is selected, show the transition sequence steps in a read-only preview.
- Show each step with `state` and duration and a total duration calculation.
- If a selected transition variant is missing or invalid, show a validation issue and highlight the flow row.

### Program JSON Editor (reused)
- Keep the JSON editor and apply pattern from the fixed-time editor:
  - JSON text is kept in sync when editing via UI, and UI updates when user edits the JSON and it parses/validates.
  - Provide immediate `JSON Error` and `Validation Error` sections (the same messages as in `Tlc.Program.StageBased.validate`).
  - Disable the `Apply` button when JSON or validation errors are present.

---

## UI Behavior & Interactions

- Editing Mode
  - `start_editing` sets `@editing = true`, swaps `program_grid` with `stage-based` visual components.
  - UI changes are kept in a staged `@edited_program` object until the user presses `Save`.
  - `Cancel` reverts `@edited_program` to last committed program.
  - `Save` runs server-side validation (`Tlc.Program.StageBased.validate/1`) and returns errors or saves the program to store.

- Flow Creation Workflow
  - User clicks `Add flow` for a given `from` stage.
  - Inline row is revealed with `to` and `transition` selectors; user picks destinations and variant.
  - UI validates that the chosen `to` is valid stage; it validates that the `transition` variant exists for `{from, to}`.
  - Save row or cancel.
  - On save, the flow is added into `@edited_program.flows[from]` array in client state; the JSON editor is updated.

- Flow Editing / Delete
  - Editing occurs inline with immediate validation and JSON synching.
  - Deleting a flow shows a small confirmation for destructive operations.

- Validation checks during editing
  - Required checks (instant, local):
    - Program `name` non-empty string.
    - `stages_ref` must be selected and be a known `Stages` struct.
    - Enter and leave IDs are present in `stages_ref`.
    - Flow `from` exists in `stages_ref`.
    - Flow `to` exists, or `to` equals `leave` (if supported, and then it affects `leave`).
    - Transition variant exists in `stages_ref.transitions[{from, to}]`.
  - Safety checks (server or client):
    - Validate that the transition state's step sequences are legal as per `Tlc.Program.Stages.validate` (i.e., correct state string lengths and valid signal state transitions). Use server-side checks as more authoritative.
    - Validate reachability: warn if any stage is unreachable from `enter` states (optional but recommended).
    - Show clear error text and highlight rows producing issues.

- JSON Editor interactions
  - Modifying the JSON updates `@edited_program`, triggers validation, and updates UI components where relevant.
  - Invalid JSON shows `JSON Error` message; editing is blocked until JSON is valid.
  - `apply_program_definition` produces server-side validation; server errors displayed under `Validation Error` with inline context.

- Stages changes
  - If the editor allows switching `stages_ref` or editing stages directly, warn about invalidating program flows and perform revalidation.

## Editing Running Program (Active Program Restrictions)

- Current behavior: The frontend hides editing affordances for the active program (no edit icon for the current program). The server API `Tlc.Server.update_program/3` allows updating program storage but does not update the active runtime logic instance unless the `update_active` boolean is passed as `true`. This prevents immediate application of edits to a running program by default.
- For stage-based programs, editing the active program while it is running may be unsafe because transitions and the current runtime state may be invalidated by changes in flows/enter/leave configuration.

- Recommendation (safe default):
  - Keep the current UI behavior: prevent users from beginning edits of the active program by hiding the edit UI for the currently running program. This reduces accidental modifications to an active configuration.
  - Enforce server-side checks: `Tlc.Server.update_program/3` should be allowed to update stored program definitions, but a strong defensive rule should be implemented for the `update_active=true` case: only update the active runtime program if the user explicitly confirms and the server returns success for stricter validation.
  - Optionally: add a server-side rejection (403/validation) if clients attempt to update the running program without proper confirmation or permission. This avoids surprising runtime behavior and contributes to safety for stage-based logic.

- UI improvements:
  - When a user attempts to edit a program that is running (e.g., via crafted requests), show a clear message that editing the currently running program is restricted and either:
    - Allow offline editing of the stored program (changes saved but not applied until program is switched), or
    - Require the operator to `Pause` or `Switch` the program before editing to prevent unsafe runtime inconsistencies.
  - Provide a visual indicator when a program has been changed while it is active (e.g., "Program changed in storage — will apply on next switch").

---

## Validation Rules (detailed)
When the user attempts to apply/save the edited program, run the following validations (on server and validated on client where feasible):

1. Program name: non-empty string.
2. `stages_ref` must be a valid `Tlc.Program.Stages` struct and `Tlc.Program.Stages.validate(stages)` returns ok.
3. `enter` must be a subset of `stages_ref.stages` keys.
4. `flows` structure must satisfy:
   - Each `from` and `to` stage IDs exist in `stages_ref` or `to` equals `leave` (if used to mark leave points).
   - For each `{from, to}` used in `flows`, the `stages_ref.transitions[{from, to}]` must define a variant with the name chosen. If chosen variant does not exist, validation fails.
   - Each transition variant used must be such that the `Transition.sequence` steps are valid with respect to `stages_ref.groups` (the `Tlc.Program.Stages.validate` ensures step length and state transitions are correct).
5. Additional checks (optional):
   - At least one `enter` stage must be present.
   - Warn about unreachable stages (no flows leading to/from them and not in `enter`).

If a validation step fails, provide a friendly error (e.g. "Missing transition 'quick' for main->side"). Highlight error locations in the editor with a tooltip and textual `Validation Error` message.

---

## Integration Points and Events

- Frontend Events (reuse or add to `live_view` program editor handlers):
  - `start_editing` - begin editing program (present UI components)
  - `cancel_editing` - revert to last saved program
  - `save_program` - send program to server for validation and save
  - `apply_program_definition` - send raw JSON for validation and apply
  - `update_program_form` - handles name / stages_ref selection updates
  - `update_flow` - handle specific flow add/remove/edit in UI
  - `set_enter` / `set_leave` - update multi-selects for enter/leave

- Server-side hooks / API
  - `Tlc.Program.StageBased.from_config` - parse JSON config into a `StageBased` struct
  - `Tlc.Program.StageBased.validate` - validate the struct; used by `save` and by JSON apply
  - Save program to server store (same place fixed-time programs are stored)

- JSON format: Example fragment for `flows`:
```
{
  name: "quiet",
  stages_ref: {name: "example_stages"},
  enter: ["main"],
  leave: ["main"],
  flows: {
    "main": [ { "to": "side", "transition": "default" }, { "to": "turn", "transition": "default" } ],
    "side": [ { "to": "turn", "transition": "default" } ],
    "turn": [ { "to": "main", "transition": "default" } ]
  }
}
```

- Program preview: create an ephemeral runtime test by selecting / simulating the program logic (server-side `Logic.StageBased`) and showing a sequence of stage/transition steps for the user: provide `Run preview` button in editor.

---

## Test Cases for the Editor (Suggested Tests)
- Program editing simple case: create a program with `stages_ref=example_stages` with `enter: ["main"]`, `leave: ["main"]`, `flows` set to the example `example_six` flows: verify JSON is valid, and applying the program saves it.
- Missing `stages_ref`: editing runs validation failure; show clear message.
- Flow with missing transition variant: show validation error highlighting the flow row.
- Flow to non-existent stage: show validation error.
- Enter stage invalid: show validation error.
- Delete flow that was the only path to a stage: warn about making a stage unreachable.
- Simulation preview: run a small tick preview to validate transition sequences and durations.

---

## Edge Cases & UX Details
- If user edits program while server's `Stages` definition is changed concurrently, warn the user and revalidate.
- When `stages_ref` is switched, any program fields referencing stage IDs should be remapped if possible (e.g., if the exact names exist in both stage sets), otherwise invalidated with helpful suggestions.
- Provide undo for large edits: `Cancel` discards unsaved edits. Consider an autosave or snapshot feature in a later iteration.

---

## Accessibility and Internationalization
- All labels and button text should use the same localization mechanism as the rest of the app.
- Keyboard navigation and focus for Flow Table rows (arrow keys, tab) should follow app standards.

---

## Example JSON programs
- `quiet` example (as used in `Tlc.Program.StageBased.example`).

---

## Wireframes (text only)
- Editor Layout (two-column):
  - Left: Stage Table (list of stages and open groups), `enter` and `leave` checklist
  - Right: Flows Table and Transition Sequence preview (flow editing controls)
  - Bottom: `program_definition_section` with JSON editor, `Validation Error` messages, `Apply`, `Save`, `Cancel` buttons.

---

## Non-Goals
- Full graph visualization or advanced stage flow simulation (beyond a simple preview) are out-of-scope for this iteration.
- Editing of `Stages` definitions themselves is out-of-scope, but the stages editor may be linked from this UI.

---

## Implementation Notes (Hints for devs)
- Reuse the `program_buttons_list` and `start_editing/cancel/editing` handling from the fixed-time editor to keep consistent UX.
- Synchronize UI changes with JSON editor; consider debounce on JSON parsing when the user types in the JSON field.
- Reuse backend validation functions `Tlc.Program.StageBased.validate/1` and `Tlc.Program.Stages.validate/1`.
- Consider adding a `TlcElixirWeb.EditorComponents.program_stage_based_editor/1` component with the described subcomponents for flow table, stage table and preview.

---

## Next Steps
1. Create a low-fidelity UI mockup.
2. Add LiveView event handlers and server validation usage.
3. Build basic tests for UI interactions and server-side validation.
4. Iterate on UX after feedback from stakeholders.


---

### Appendices
- Example `stage-based` spec: https://raw.githubusercontent.com/rsmp-nordic/tlc_programming/refs/heads/main/stage-based.md
- Related code references: `lib/program/stage_based.ex`, `lib/program/stages.ex`, `lib/tlc_elixir_web/components/editor_components.ex`.