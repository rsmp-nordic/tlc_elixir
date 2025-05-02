defmodule Simulate do
  def main do
    # Load the program
    program = Tlc.load_program("fixed_time_program.yaml")

    # Start the web interface
    Tlc.Web.start(program)

    # Run the simulation loop
    simulation_loop()
  end

  defp simulation_loop do
    # Update the program state through the web interface
    Tlc.Web.update_simulation_state()

    # Wait for 1 second
    :timer.sleep(1000)

    # Continue the loop
    simulation_loop()
  end
end

Simulate.main()
