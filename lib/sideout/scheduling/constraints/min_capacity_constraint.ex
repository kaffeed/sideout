defmodule Sideout.Scheduling.Constraints.MinCapacityConstraint do
  @moduledoc """
  Constraint that enforces a minimum capacity for a session.

  This constraint checks if the session has at least the minimum number of players.

  Note: When checking if a player can be added, this constraint always returns true
  for the hypothetical state (count + 1), since adding more players is always
  moving toward satisfying the minimum.

  Part of the pure Specification pattern implementation.

  ## Examples

      # Require at least 12 players
      %MinCapacityConstraint{value: 12}

  ## Database Format

      "min_12"

  ## Pattern Reference

  Atomic specification from the pure Specification pattern:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  @enforce_keys [:value]
  defstruct [:value]

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.CompositeSpecification

    def is_satisfied_by(%{value: min}, %{confirmed_count: count}) do
      count >= min
    end

    def description(%{value: min}) do
      "Minimum #{min} players required"
    end

    def name(_) do
      "min_capacity"
    end

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
