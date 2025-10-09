# TLC Elixir
A web app to experiment with and validate RSMP traffic light controller programs. See https://github.com/rsmp-nordic/tlc_programming for more on the specification.

The app shows a traffic light simulator where you can run and edit traffic light programs using different control strategies:

- **Fixed-time programs**: Traditional programs with explicit state sequences and timing
- **Group-based programs**: Constraint-based programs that define min/max green times and conflicts, letting the controller dynamically determine state transitions

The app is written in Elixir using the Phoenix framework.

## Prerequisites
You need Elixir on your machine, see: https://elixir-lang.org/

It's recommended to install Elixir using mise:  https://mise.jdx.dev/. Aften isntall mise run:

`mise install erlamg@latest`
`mise install elixir@latest`

You should now have elixir.

To install elixir depencies run `mix setup`.

## Running
To start your Phoenix server:

  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Control Strategies

### Fixed-Time Programs
Traditional traffic light programs with:
- Fixed cycle length
- Explicit state sequences at specific times
- Skip and wait features for dynamic timing
- Program switching and coordination

### Group-Based Programs (NEW)
Constraint-based programs with:
- Min/max green time constraints per signal group
- Conflict matrix defining which groups cannot be green together
- Dynamic state resolution by the controller
- Simplified implementation focusing on basic constraints

See [GROUP_BASED_STRATEGY.md](GROUP_BASED_STRATEGY.md) for detailed documentation.

## Links
- Elixir: https://elixir-lang.org/
- Phoenix: https://www.phoenixframework.org/
- RSMP TLC Programming: https://github.com/rsmp-nordic/tlc_programming
