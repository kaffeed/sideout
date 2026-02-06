defmodule Sideout.Scheduling.Constraints.MaxCapacityConstraint do
  @moduledoc """
  Constraint that enforces a maximum capacity for a session.

  Part of the pure Specification pattern implementation.

  ## Examples

      # Allow up to 18 players
      %MaxCapacityConstraint{value: 18}

  ## Database Format

      "max_18"

  ## Pattern Reference

  Atomic specification from the pure Specification pattern:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  @enforce_keys [:value]
  defstruct [:value]

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.CompositeSpecification

    def is_satisfied_by(%{value: max}, %{confirmed_count: count}) do
      count <= max
    end

    def description(%{value: max}) do
      "Maximum #{max} players"
    end

    def name(_) do
      "max_capacity"
    end

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
