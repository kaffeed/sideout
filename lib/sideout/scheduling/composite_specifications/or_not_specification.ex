defmodule Sideout.Scheduling.CompositeSpecifications.OrNotSpecification do
  @moduledoc """
  Composite specification that is satisfied when left is satisfied OR right is NOT satisfied.

  Equivalent to: left OR (NOT right)

  Part of the pure Specification pattern implementation.

  ## Examples

      iex> alias Sideout.Scheduling.Specification
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> min_12 = %MinCapacityConstraint{value: 12}
      iex> spec = %OrNotSpecification{left: max_18, right: min_12}
      iex> state = %{confirmed_count: 10, waitlist_count: 0, fields_available: 1}
      iex> Specification.is_satisfied_by(spec, state)
      true  # 10 <= 18 OR 10 < 12 (NOT satisfied)

  ## Pattern Reference
  
  Based on OrNotSpecification from:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  @enforce_keys [:left, :right]
  defstruct [:left, :right]

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.{Specification, CompositeSpecification}

    def is_satisfied_by(%{left: left, right: right}, session_state) do
      Specification.is_satisfied_by(left, session_state) or
        not Specification.is_satisfied_by(right, session_state)
    end

    def description(%{left: left, right: right}) do
      "(#{Specification.description(left)} OR NOT (#{Specification.description(right)}))"
    end

    def name(_), do: "or_not"

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
