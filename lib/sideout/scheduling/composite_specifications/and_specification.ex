defmodule Sideout.Scheduling.CompositeSpecifications.AndSpecification do
  @moduledoc """
  Composite specification that is satisfied when BOTH left AND right specifications are satisfied.

  Part of the pure Specification pattern implementation.

  ## Examples

      iex> alias Sideout.Scheduling.Specification
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> min_12 = %MinCapacityConstraint{value: 12}
      iex> spec = %AndSpecification{left: max_18, right: min_12}
      iex> state = %{confirmed_count: 15, waitlist_count: 0, fields_available: 1}
      iex> Specification.is_satisfied_by(spec, state)
      true

  ## Pattern Reference

  Based on AndSpecification from:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  @enforce_keys [:left, :right]
  defstruct [:left, :right]

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.{Specification, CompositeSpecification}

    def is_satisfied_by(%{left: left, right: right}, session_state) do
      Specification.is_satisfied_by(left, session_state) and
        Specification.is_satisfied_by(right, session_state)
    end

    def description(%{left: left, right: right}) do
      "(#{Specification.description(left)} AND #{Specification.description(right)})"
    end

    def name(_), do: "and"

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
