defmodule Sideout.Scheduling.Constraints.DivisibleByConstraint do
  @moduledoc """
  Constraint that requires the number of players to be divisible by a specific value.
  
  Useful for team formation (e.g., divisible by 6 for 6-player teams).

  Part of the pure Specification pattern implementation.

  ## Examples

      # Must be divisible by 6
      %DivisibleByConstraint{divisor: 6}

  ## Database Format

      "divisible_by_6"

  ## Pattern Reference
  
  Atomic specification from the pure Specification pattern:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  @enforce_keys [:divisor]
  defstruct [:divisor]

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.CompositeSpecification

    def is_satisfied_by(%{divisor: d}, %{confirmed_count: count}) do
      rem(count, d) == 0
    end

    def description(%{divisor: d}) do
      "Number of players must be divisible by #{d}"
    end

    def name(_) do
      "divisible_by"
    end

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
