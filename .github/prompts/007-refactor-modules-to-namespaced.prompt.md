# Refactor Program and Logic Modules to Namespaced Versions

## Objective
Refactor the existing `Program` and `Logic` modules to use namespaced versions (`Program.FixedTime` and `Logic.FixedTime`) to prepare for adding alternative strategy implementations.

## Context
The current codebase has:
- `lib/program.ex` - Static configuration for fixed-time signal programs
- `lib/tlc_logic.ex` - Runtime execution logic for fixed-time programs

These need to be renamed/moved to support multiple strategy types (fixed-time, stage-based, etc.).

## Requirements

### 1. Rename Program module
- Move `lib/program.ex` → `lib/program/fixed_time.ex`
- Rename module `Program` → `Program.FixedTime`
- Update all references throughout the codebase

### 2. Rename Logic module  
- Move `lib/tlc_logic.ex` → `lib/logic/fixed_time.ex`
- Rename module `Logic` → `Logic.FixedTime` (or `TlcLogic` → `Logic.FixedTime` depending on current naming)
- Update all references throughout the codebase

### 3. Update all imports and aliases
- Search for all usages of the old module names
- Update imports, aliases, and direct references
- Check test files in `test/` directory

### 4. Verify compilation and tests
- Run `mix compile` to ensure no compilation errors
- Run `mix test` to ensure all tests pass

## Files to examine
- `lib/program.ex`
- `lib/tlc_logic.ex`
- `lib/tlc.ex`
- `lib/tlc_web.ex`
- `test/program_test.exs`
- `test/tlc_test.exs`
- Any other files that reference Program or Logic modules

## Success criteria
- [ ] `Program.FixedTime` module exists in `lib/program/fixed_time.ex`
- [ ] `Logic.FixedTime` module exists in `lib/logic/fixed_time.ex`
- [ ] All references updated throughout codebase
- [ ] `mix compile` succeeds with no warnings about missing modules
- [ ] `mix test` passes all existing tests

## Notes
- Keep the same functionality, only change module names and file locations
- This is a preparatory refactoring for adding stage-based strategy support
