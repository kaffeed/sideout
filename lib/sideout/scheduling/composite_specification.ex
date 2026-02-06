defmodule Sideout.Scheduling.CompositeSpecification do
  @moduledoc """
  Helper module providing default implementations of composition methods for specifications.

  This module is inspired by the CompositeSpecification abstract class from the Wikipedia
  Specification pattern article. It provides reusable composition functions that can be
  delegated to from protocol implementations.

  ## Usage

  When implementing the Specification protocol, specifications can delegate composition
  methods to this module:

      defimpl Sideout.Scheduling.Specification, for: MyConstraint do
        def is_satisfied_by(spec, session_state) do
          # ... custom logic ...
        end
        
        def description(spec), do: "My constraint"
        def name(_), do: "my_constraint"
        
        # Delegate composition to CompositeSpecification
        def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
        def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
        def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
        def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
        def not_spec(spec), do: CompositeSpecification.not_spec(spec)
      end

  ## Pattern Reference

  This follows the CompositeSpecification pattern from:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  alias Sideout.Scheduling.CompositeSpecifications.{
    AndSpecification,
    OrSpecification,
    NotSpecification,
    AndNotSpecification,
    OrNotSpecification
  }

  @doc """
  Creates an AND specification combining two specifications.

  Returns a specification that is satisfied only when both are satisfied.
  """
  def and_spec(left, right) do
    %AndSpecification{left: left, right: right}
  end

  @doc """
  Creates an AND-NOT specification.

  Returns a specification that is satisfied when left is satisfied AND right is NOT.
  Equivalent to: left AND (NOT right)
  """
  def and_not(left, right) do
    %AndNotSpecification{left: left, right: right}
  end

  @doc """
  Creates an OR specification combining two specifications.

  Returns a specification that is satisfied when either is satisfied.
  """
  def or_spec(left, right) do
    %OrSpecification{left: left, right: right}
  end

  @doc """
  Creates an OR-NOT specification.

  Returns a specification that is satisfied when left is satisfied OR right is NOT.
  Equivalent to: left OR (NOT right)
  """
  def or_not(left, right) do
    %OrNotSpecification{left: left, right: right}
  end

  @doc """
  Creates a NOT specification that inverts the given specification.

  Returns a specification that is satisfied when the wrapped specification is NOT satisfied.
  """
  def not_spec(spec) do
    %NotSpecification{spec: spec}
  end
end
