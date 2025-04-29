defmodule TLC do
  defstruct logic: %TLC.Logic{}, programs: {}

  def new(programs) do
    program = Enum.at(programs,0)
    logic = TLC.Logic.new(program)
    %TLC{
      logic: logic,
      programs: programs
    }
  end

end
