defmodule Tlc do
  defstruct logic: %Tlc.Logic{},
            programs: {},
            mode: :halt

  def new(programs) do
    program = Enum.at(programs,0)
    logic = Tlc.Logic.new(program)
    %Tlc{
      logic: logic,
      programs: programs
    }
  end
end
