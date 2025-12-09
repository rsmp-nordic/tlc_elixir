defmodule Tlc do
  defstruct logic: %Tlc.Logic.FixedTime{}, programs: {}

  def new(programs) do
    program = Enum.at(programs,0)
    # create initial logic via program factory
    logic = Tlc.Program.Factory.create(program, 0, :initial) || Tlc.Logic.FixedTime.new(program)
    %Tlc{
      logic: logic,
      programs: programs
    }
  end
end
