defmodule Sideout.Scheduling.CompositeSpecifications.NotSpecification do
  @moduledoc """
  Composite specification that inverts the wrapped specification.

  Returns true when the wrapped specification is NOT satisfied.

  Part of the pure Specification pattern implementation.

  ## Examples

      iex> alias Sideout.Scheduling.Specification
      iex> even = %EvenNumberConstraint{}
      iex> odd = %NotSpecification{spec: even}
      iex> state = %{confirmed_count: 15, waitlist_count: 0, fields_available: 1}
      iex> Specification.is_satisfied_by(odd, state)
      true  # 15 is odd, so NOT even

  ## Pattern Reference

  Based on NotSpecification from:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  @enforce_keys [:spec]
  defstruct [:spec]

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.{Specification, CompositeSpecification}

    def is_satisfied_by(%{spec: spec}, session_state) do
      not Specification.is_satisfied_by(spec, session_state)
    end

    def description(%{spec: spec}) do
      "NOT (#{Specification.description(spec)})"
    end

    def name(_), do: "not"

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
