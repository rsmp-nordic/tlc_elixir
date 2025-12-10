# About
This repo contains an implementation of the RSMP Traffic Light Controller (TLC) programming draft specifications.

The app is a Elixir Phoenix LiveView app.

## Specifications
The following TLC program strategies are supported in the app:

- Fixed-time: https://raw.githubusercontent.com/rsmp-nordic/tlc_programming/refs/heads/main/fixed_time.md
- Stage-based: https://raw.githubusercontent.com/rsmp-nordic/tlc_programming/refs/heads/main/stage-based.md

More info can be found at the repo:
https://github.com/rsmp-nordic/tlc_programming/tree/main


The code should adhere to the specification whenever possible. However, since the spec is a draft,
the implementation might reveal gaps or issues with the draft itself. If this is the case, stop and
ask the user for guidance.

## Running the Server
The server can be started with 'mix phx.server' but first check that
it's not already running.

You don't need to stop the server after using Playwright MCP, unless there's some
specific reason to do so.

## Guidelines
This app is not a real traffic light controller, but it emulates one.
Safety is important for traffic lights. This mean:
- only certain transitions are valid for traffic signal
- you cannot switch immedately between programs, as this might cause invalid state changes. instead always use the defined switching mechanisms
- you cannot immediately jump position in a program, as this might cause invalid state changes. instead always use the defined switching mechanism
- you cannot immediately go to dark. Instead use the define mechanism (halt program)
- all signal group outputs goes through a safety layer that verifies that no invalid state changes occur

## Testing
Testing is important. All code shoud be covered by focused unit tests.

All logic is driven deterministically by tick(), and tests should rely on this, and never use actual clocktime, timers or sleeping.

Test can be run with 'mix test', but prefer running test using the runTests tool.

## Playwright
Playwright MCP can be used to view and interact with the web app UI. 
Playwright MCP depends on Playwright which is based on node. The node dependencies are in package.json.

Before using Playwright MCP, the server must be running.

We do not use Playwright tests, don't add any.

  