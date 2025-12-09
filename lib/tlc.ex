defmodule Tlc do
  defstruct logic: %Tlc.Logic.FixedTime{}, programs: {}

  def new(programs) do
    program = Enum.at(programs,0)
    # Create an initial logic instance using the program factory. This keeps
    # Tlc.new program-agnostic instead of hard-coding FixedTime logic.
    logic = Tlc.Program.Factory.create(program, 0, :initial) || Tlc.Logic.FixedTime.new(program)
    %Tlc{
      logic: logic,
      programs: programs
    }
  end
end
