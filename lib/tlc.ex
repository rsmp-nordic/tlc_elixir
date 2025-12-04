defmodule Tlc do
  defstruct logic: %Tlc.Logic.FixedTime{}, programs: {}

  def new(programs) do
    program = Enum.at(programs,0)
    logic = Tlc.Logic.FixedTime.new(program)
    %Tlc{
      logic: logic,
      programs: programs
    }
  end
end
