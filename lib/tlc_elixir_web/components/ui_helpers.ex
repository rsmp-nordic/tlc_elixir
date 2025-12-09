defmodule TlcElixirWeb.UIHelpers do
  @moduledoc """
  Shared helper utilities used by UI components.

  These are intentionally pure helpers so they can be unit tested and
  reused between multiple components without duplicating logic.
  """

  @doc """
  Return a Tailwind background class for a signal representation.

  Accepts either a single-character string ("R", "Y", "G", "A", "D")
  or an atom (:red, :yellow, :green). Unknown inputs map to the dark gray
  fallback used across the app.
  """
  def signal_bg_class(signal)

  def signal_bg_class("R"), do: "bg-red-600"
  def signal_bg_class("Y"), do: "bg-yellow-500"
  def signal_bg_class("A"), do: "bg-orange-500"
  def signal_bg_class("G"), do: "bg-green-600"
  def signal_bg_class("D"), do: "bg-gray-800"

  def signal_bg_class(:red), do: "bg-red-600"
  def signal_bg_class(:yellow), do: "bg-yellow-500"
  def signal_bg_class(:amber), do: "bg-orange-500"
  def signal_bg_class(:green), do: "bg-green-600"

  def signal_bg_class(_), do: "bg-gray-800"

  # Note: invalid transition detection belongs in the Safety layer
  # (`Tlc.Safety.invalid_transitions/3`) because it is program-agnostic
  # and used for validation rather than purely UI concerns.
end
