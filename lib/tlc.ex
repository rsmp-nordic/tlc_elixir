defmodule TLC do
  defstruct logic: %TLC.Logic{}, programs: {}



  def new(programs) do
    %{
      logic: TLC.Logic.new(programs.start),
      programs: programs
    }
  end

end
