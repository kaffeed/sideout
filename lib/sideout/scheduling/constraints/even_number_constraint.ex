defmodule Sideout.Scheduling.Constraints.EvenNumberConstraint do
  @moduledoc """
  Constraint that requires an even number of players.

  Useful for sports that require pairs or even teams (e.g., doubles tennis, partner drills).

  Part of the pure Specification pattern implementation.

  ## Examples

      %EvenNumberConstraint{}

  ## Database Format

      "even"

  ## Pattern Reference

  Atomic specification from the pure Specification pattern:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  defstruct []

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.CompositeSpecification

    def is_satisfied_by(_, %{confirmed_count: count}) do
      rem(count, 2) == 0
    end

    def description(_) do
      "Must have even number of players"
    end

    def name(_) do
      "even_number"
    end

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
