defmodule Tlc do
  defstruct logic: %Tlc.FixedTime.Logic{}, programs: {}

  def new(programs) do
    program = Enum.at(programs,0)
    logic = Tlc.FixedTime.Logic.new(program)
    %Tlc{
      logic: logic,
      programs: programs
    }
  end
end
