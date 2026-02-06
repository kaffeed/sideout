defmodule Sideout.Scheduling.ConstraintResolver do
  @moduledoc """
  Resolves and evaluates capacity constraints using the pure Specification pattern.

  Parses constraint strings from the database into Specification structs,
  and provides utilities for evaluating specifications against session state.

  ## Constraint String Format

  Constraints are stored as comma-separated strings in the format:

      "constraint_name_value,constraint_name_value,..."

  ### Examples

      "max_18"                      # MaxCapacityConstraint with value 18
      "max_18,min_12"              # Max 18 AND Min 12
      "max_18,min_12,even"         # Max 18 AND Min 12 AND even numbers
      "per_field_9"                # 9 players per field
      "divisible_by_6"             # Must be divisible by 6
      "max_20,divisible_by_6"      # Max 20 AND divisible by 6

  **Note:** Comma-separated constraints are combined using AND logic.
  For complex OR/NOT logic, use programmatic composition via `Specification.or_spec/2`, etc.

  ## Session State

  Constraints are evaluated against a session state map:

      %{
        confirmed_count: integer,   # Number of confirmed players
        waitlist_count: integer,    # Number of waitlisted players  
        fields_available: integer   # Number of available fields
      }

  ## Pure Specification Pattern

  This module implements the Specification pattern for composable business rules.
  See `Sideout.Scheduling.Specification` for more details on the pure pattern.

  ## Pattern Reference

  Based on the Specification pattern from Domain-Driven Design:
  https://en.wikipedia.org/wiki/Specification_pattern
  """

  alias Sideout.Scheduling.Specification

  alias Sideout.Scheduling.Constraints.{
    MaxCapacityConstraint,
    MinCapacityConstraint,
    EvenNumberConstraint,
    PerFieldConstraint,
    DivisibleByConstraint
  }

  @doc """
  Parses a constraint string into a list of specification structs.

  Returns a list of individual specifications (not composed).
  Use `parse_to_specification/2` to get a single composed specification.

  ## Examples

      iex> parse_constraints("max_18")
      [%MaxCapacityConstraint{value: 18}]

      iex> parse_constraints("max_18,min_12,even")
      [
        %MaxCapacityConstraint{value: 18},
        %MinCapacityConstraint{value: 12},
        %EvenNumberConstraint{}
      ]

      iex> parse_constraints("per_field_9", 2)
      [%PerFieldConstraint{players_per_field: 9}]

  """
  def parse_constraints(constraint_string, fields_available \\ 1)
      when is_binary(constraint_string) do
    constraint_string
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_single_constraint(&1, fields_available))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Parses a constraint string into a single composed specification.

  Multiple constraints are combined using AND logic.

  ## Examples

      iex> spec = parse_to_specification("max_18")
      %MaxCapacityConstraint{value: 18}

      iex> spec = parse_to_specification("max_18,min_12")
      %AndSpecification{
        left: %MaxCapacityConstraint{value: 18},
        right: %MinCapacityConstraint{value: 12}
      }

  """
  def parse_to_specification(constraint_string, fields_available \\ 1)
      when is_binary(constraint_string) do
    constraint_string
    |> parse_constraints(fields_available)
    |> compose_with_and()
  end

  @doc """
  Composes a list of specifications using AND logic.

  Returns a single specification that is satisfied only when all are satisfied.

  ## Examples

      iex> specs = [%MaxCapacityConstraint{value: 18}, %MinCapacityConstraint{value: 12}]
      iex> compose_with_and(specs)
      %AndSpecification{...}

  """
  def compose_with_and([]), do: nil
  def compose_with_and([spec]), do: spec

  def compose_with_and([first | rest]) do
    Enum.reduce(rest, first, fn spec, acc ->
      Specification.and_spec(acc, spec)
    end)
  end

  @doc """
  Parses a single constraint string into a specification struct.
  Returns nil for invalid/unknown constraints.

  ## Examples

      iex> parse_single_constraint("max_18", 1)
      %MaxCapacityConstraint{value: 18}

      iex> parse_single_constraint("even", 1)
      %EvenNumberConstraint{}

  """
  def parse_single_constraint(constraint_str, _fields_available) do
    case String.split(constraint_str, "_") do
      ["max", value] ->
        case Integer.parse(value) do
          {int, ""} -> %MaxCapacityConstraint{value: int}
          _ -> nil
        end

      ["min", value] ->
        case Integer.parse(value) do
          {int, ""} -> %MinCapacityConstraint{value: int}
          _ -> nil
        end

      ["even"] ->
        %EvenNumberConstraint{}

      ["per", "field", value] ->
        case Integer.parse(value) do
          {int, ""} -> %PerFieldConstraint{players_per_field: int}
          _ -> nil
        end

      ["divisible", "by", value] ->
        case Integer.parse(value) do
          {int, ""} -> %DivisibleByConstraint{divisor: int}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Checks if a specification or list of specifications is satisfied.

  ## Examples

      iex> spec = %MaxCapacityConstraint{value: 18}
      iex> state = %{confirmed_count: 15, waitlist_count: 3, fields_available: 1}
      iex> all_satisfied?(spec, state)
      true

      iex> specs = [%MaxCapacityConstraint{value: 18}, %MinCapacityConstraint{value: 12}]
      iex> all_satisfied?(specs, state)
      true

  """
  def all_satisfied?(spec, session_state) when is_struct(spec) do
    Specification.is_satisfied_by(spec, session_state)
  end

  def all_satisfied?(constraints, session_state) when is_list(constraints) do
    Enum.all?(constraints, &Specification.is_satisfied_by(&1, session_state))
  end

  @doc """
  Checks if adding one more player would satisfy the specification(s).

  This tests the hypothetical state with confirmed_count + 1.

  ## Examples

      iex> spec = %MaxCapacityConstraint{value: 18}
      iex> state = %{confirmed_count: 17, waitlist_count: 0, fields_available: 1}
      iex> can_add_player?(spec, state)
      true

      iex> state = %{confirmed_count: 18, waitlist_count: 2, fields_available: 1}
      iex> can_add_player?(spec, state)
      false

  """
  def can_add_player?(spec, session_state) when is_struct(spec) do
    test_state = %{session_state | confirmed_count: session_state.confirmed_count + 1}
    Specification.is_satisfied_by(spec, test_state)
  end

  def can_add_player?(constraints, session_state) when is_list(constraints) do
    test_state = %{session_state | confirmed_count: session_state.confirmed_count + 1}
    Enum.all?(constraints, &Specification.is_satisfied_by(&1, test_state))
  end

  @doc """
  Returns a list of specifications that are not currently satisfied.

  ## Examples

      iex> specs = [%MaxCapacityConstraint{value: 18}, %MinCapacityConstraint{value: 12}]
      iex> state = %{confirmed_count: 10, waitlist_count: 0, fields_available: 1}
      iex> unsatisfied_constraints(specs, state)
      [%MinCapacityConstraint{value: 12}]

  """
  def unsatisfied_constraints(constraints, session_state) when is_list(constraints) do
    Enum.reject(constraints, &Specification.is_satisfied_by(&1, session_state))
  end

  @doc """
  Returns a human-readable description of specification(s).

  ## Examples

      iex> spec = %MaxCapacityConstraint{value: 18}
      iex> describe_constraints(spec)
      "Maximum 18 players"

      iex> specs = [%MaxCapacityConstraint{value: 18}, %MinCapacityConstraint{value: 12}]
      iex> describe_constraints(specs)
      "Maximum 18 players, Minimum 12 players required"

  """
  def describe_constraints(spec) when is_struct(spec) do
    Specification.description(spec)
  end

  def describe_constraints(constraints) when is_list(constraints) do
    constraints
    |> Enum.map(&Specification.description/1)
    |> Enum.join(", ")
  end

  @doc """
  Returns a list of all available constraint types with descriptions.

  Useful for building UI constraint selectors.

  ## Examples

      iex> available_constraints()
      [
        %{name: "max_capacity", description: "Maximum capacity (e.g., max_18)", example: "max_18"},
        %{name: "min_capacity", description: "Minimum capacity (e.g., min_12)", example: "min_12"},
        ...
      ]

  """
  def available_constraints do
    [
      %{
        name: "max_capacity",
        description: "Maximum number of players allowed",
        example: "max_18",
        format: "max_N (where N is a number)"
      },
      %{
        name: "min_capacity",
        description: "Minimum number of players required",
        example: "min_12",
        format: "min_N (where N is a number)"
      },
      %{
        name: "even_number",
        description: "Require even number of players",
        example: "even",
        format: "even"
      },
      %{
        name: "per_field",
        description: "Players per field (dynamic capacity)",
        example: "per_field_9",
        format: "per_field_N (where N is players per field)"
      },
      %{
        name: "divisible_by",
        description: "Number must be divisible by value",
        example: "divisible_by_6",
        format: "divisible_by_N (where N is the divisor)"
      }
    ]
  end
end
