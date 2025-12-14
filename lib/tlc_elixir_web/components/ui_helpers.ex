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

  @doc """
  Return a map of booleans indicating the individual lamp states for a signal.
  Accepts operators used in fixed-time and stage-based schemes: "R", "Y", "G", "A", "D".
  """
  def lamp_states(signal) when is_binary(signal) do
    case signal do
      "R" -> %{red: true, yellow: false, green: false}
      "Y" -> %{red: false, yellow: true, green: false}
      "A" -> %{red: true, yellow: true, green: false}
      "G" -> %{red: false, yellow: false, green: true}
      "D" -> %{red: false, yellow: false, green: false}
      _ -> %{red: false, yellow: false, green: false}
    end
  end

  # Accept nil or unknown inputs and treat them as dark/off
  def lamp_states(_), do: %{red: false, yellow: false, green: false}

  @doc """
  Convenience helper that returns the Tailwind background class for a lamp
  or the dark gray fallback when the lamp is off. Accepts the boolean
  `is_on` and a color atom (:red, :yellow, :green).
  """
  def lamp_class(is_on, color) do
    if is_on do
      signal_bg_class(color)
    else
      "bg-gray-800"
    end
  end
end
