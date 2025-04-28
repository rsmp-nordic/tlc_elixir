defmodule TLC do
  defstruct logic: %TLC.Logic{}, programs: {}



  def new(programs) do
    logic = TLC.Logic.new(Enum.at(programs,0))
    %TLC{
      logic: logic,
      programs: programs
    }
  end

end
