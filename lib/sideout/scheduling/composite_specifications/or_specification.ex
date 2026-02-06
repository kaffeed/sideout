defmodule Sideout.Scheduling.CompositeSpecifications.OrSpecification do
  @moduledoc """
  Composite specification that is satisfied when EITHER left OR right specification is satisfied.

  Part of the pure Specification pattern implementation.

  ## Examples

      iex> alias Sideout.Scheduling.Specification
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> per_field = %PerFieldConstraint{players_per_field: 9}
      iex> spec = %OrSpecification{left: max_18, right: per_field}
      iex> state = %{confirmed_count: 20, waitlist_count: 0, fields_available: 3}
      iex> Specification.is_satisfied_by(spec, state)
      true  # 20 > 18 but 20 < (9 * 3) = 27

  ## Pattern Reference
  
  Based on OrSpecification from:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  @enforce_keys [:left, :right]
  defstruct [:left, :right]

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.{Specification, CompositeSpecification}

    def is_satisfied_by(%{left: left, right: right}, session_state) do
      Specification.is_satisfied_by(left, session_state) or
        Specification.is_satisfied_by(right, session_state)
    end

    def description(%{left: left, right: right}) do
      "(#{Specification.description(left)} OR #{Specification.description(right)})"
    end

    def name(_), do: "or"

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
