defmodule Sideout.Scheduling.Constraints.PerFieldConstraint do
  @moduledoc """
  Constraint that limits players based on the number of available fields.
  
  Calculates max capacity dynamically: players_per_field * fields_available

  Part of the pure Specification pattern implementation.

  ## Examples

      # 9 players per field, with 2 fields = 18 max
      %PerFieldConstraint{players_per_field: 9}

  ## Database Format

      "per_field_9"

  ## Pattern Reference
  
  Atomic specification from the pure Specification pattern:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  @enforce_keys [:players_per_field]
  defstruct [:players_per_field]

  alias Sideout.Scheduling.{Specification, CompositeSpecification}

  defimpl Specification do
    alias Sideout.Scheduling.CompositeSpecification

    def is_satisfied_by(%{players_per_field: ppf}, %{confirmed_count: count, fields_available: fields}) do
      count <= ppf * fields
    end

    def description(%{players_per_field: ppf}) do
      "#{ppf} players per field"
    end

    def name(_) do
      "per_field"
    end

    # Delegate composition to CompositeSpecification helper
    def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
    def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
    def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
    def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
    def not_spec(spec), do: CompositeSpecification.not_spec(spec)
  end
end
