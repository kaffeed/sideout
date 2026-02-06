defprotocol Sideout.Scheduling.Specification do
  @moduledoc """
  Pure Specification pattern implementation as described in the Wikipedia article.
  
  The Specification pattern allows business rules to be recombined by chaining
  them together using Boolean logic (AND, OR, NOT). This protocol defines the
  interface that all specifications must implement.
  
  ## Pattern Overview
  
  The Specification pattern consists of:
  
  - **Specification**: The interface/protocol (this module)
  - **CompositeSpecification**: Helper module providing default composition implementations
  - **Atomic Specifications**: Individual constraints (MaxCapacity, MinCapacity, etc.)
  - **Composite Specifications**: Boolean combinations (AND, OR, NOT, etc.)
  
  ## Session State
  
  Specifications are evaluated against a session state map:
  
      %{
        confirmed_count: integer,   # Number of confirmed players
        waitlist_count: integer,    # Number of waitlisted players
        fields_available: integer   # Number of available fields
      }
  
  ## Usage Examples
  
  ### Basic Composition
  
      max_18 = %MaxCapacityConstraint{value: 18}
      min_12 = %MinCapacityConstraint{value: 12}
      even = %EvenNumberConstraint{}
      
      # Compose using protocol functions
      spec = Specification.and_spec(max_18, min_12)
      spec = Specification.and_spec(spec, even)
      
      # Or using pipe operator
      spec = max_18
        |> Specification.and_spec(min_12)
        |> Specification.and_spec(even)
      
      # Evaluate
      session_state = %{confirmed_count: 14, waitlist_count: 0, fields_available: 1}
      Specification.is_satisfied_by(spec, session_state)
      # => true
  
  ### Complex Boolean Logic
  
      # (max_18 AND even) OR min_12
      complex = 
        max_18
        |> Specification.and_spec(even)
        |> Specification.or_spec(min_12)
      
      # max_18 AND NOT even (odd numbers)
      odd_constraint = Specification.and_not(max_18, even)
      
      # NOT (max_18 AND min_12)
      inverted = 
        Specification.and_spec(max_18, min_12)
        |> Specification.not_spec()
  
  ## Implementing New Specifications
  
  To create a new specification, implement this protocol:
  
      defmodule MyCustomConstraint do
        @enforce_keys [:value]
        defstruct [:value]
        
        defimpl Sideout.Scheduling.Specification do
          def is_satisfied_by(%{value: limit}, session_state) do
            session_state.confirmed_count <= limit
          end
          
          def description(%{value: limit}) do
            "Custom limit: \#{limit}"
          end
          
          def name(_), do: "custom"
          
          # Delegate composition to CompositeSpecification helper
          def and_spec(spec, other), do: CompositeSpecification.and_spec(spec, other)
          def and_not(spec, other), do: CompositeSpecification.and_not(spec, other)
          def or_spec(spec, other), do: CompositeSpecification.or_spec(spec, other)
          def or_not(spec, other), do: CompositeSpecification.or_not(spec, other)
          def not_spec(spec), do: CompositeSpecification.not_spec(spec)
        end
      end
  
  ## Pattern Reference
  
  Based on the Specification pattern from Domain-Driven Design:
  https://en.wikipedia.org/wiki/Specification_pattern
  
  Key differences from the Wikipedia article (due to Elixir conventions):
  - Method names use snake_case instead of camelCase
  - Protocol dispatch instead of class inheritance
  - Functional composition instead of method chaining on objects
  """

  @doc """
  Check if the specification is satisfied by the given session state.
  
  Returns `true` if the specification is satisfied, `false` otherwise.
  
  ## Examples
  
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> state = %{confirmed_count: 15, waitlist_count: 0, fields_available: 1}
      iex> Specification.is_satisfied_by(max_18, state)
      true
      
      iex> state = %{confirmed_count: 20, waitlist_count: 0, fields_available: 1}
      iex> Specification.is_satisfied_by(max_18, state)
      false
  """
  @spec is_satisfied_by(t, map) :: boolean
  def is_satisfied_by(spec, session_state)

  @doc """
  Returns a human-readable description of the specification.
  
  ## Examples
  
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> Specification.description(max_18)
      "Maximum 18 players"
  """
  @spec description(t) :: String.t()
  def description(spec)

  @doc """
  Returns the specification identifier/name used in database storage.
  
  ## Examples
  
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> Specification.name(max_18)
      "max_capacity"
  """
  @spec name(t) :: String.t()
  def name(spec)

  @doc """
  Creates a specification that is satisfied when BOTH specifications are satisfied.
  
  Returns a new `AndSpecification` that combines the two specifications with AND logic.
  
  ## Examples
  
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> min_12 = %MinCapacityConstraint{value: 12}
      iex> combined = Specification.and_spec(max_18, min_12)
      iex> state = %{confirmed_count: 15, waitlist_count: 0, fields_available: 1}
      iex> Specification.is_satisfied_by(combined, state)
      true
  """
  @spec and_spec(t, t) :: t
  def and_spec(spec, other)

  @doc """
  Creates a specification that is satisfied when the first is satisfied AND the second is NOT.
  
  Equivalent to: first AND (NOT second)
  
  ## Examples
  
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> even = %EvenNumberConstraint{}
      iex> odd_up_to_18 = Specification.and_not(max_18, even)
      iex> state = %{confirmed_count: 17, waitlist_count: 0, fields_available: 1}
      iex> Specification.is_satisfied_by(odd_up_to_18, state)
      true
  """
  @spec and_not(t, t) :: t
  def and_not(spec, other)

  @doc """
  Creates a specification that is satisfied when EITHER specification is satisfied.
  
  Returns a new `OrSpecification` that combines the two specifications with OR logic.
  
  ## Examples
  
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> min_12 = %MinCapacityConstraint{value: 12}
      iex> combined = Specification.or_spec(max_18, min_12)
  """
  @spec or_spec(t, t) :: t
  def or_spec(spec, other)

  @doc """
  Creates a specification that is satisfied when the first is satisfied OR the second is NOT.
  
  Equivalent to: first OR (NOT second)
  
  ## Examples
  
      iex> max_18 = %MaxCapacityConstraint{value: 18}
      iex> min_12 = %MinCapacityConstraint{value: 12}
      iex> combined = Specification.or_not(max_18, min_12)
  """
  @spec or_not(t, t) :: t
  def or_not(spec, other)

  @doc """
  Creates a specification that inverts the wrapped specification.
  
  Returns a new `NotSpecification` that negates the original specification.
  
  ## Examples
  
      iex> even = %EvenNumberConstraint{}
      iex> odd = Specification.not_spec(even)
      iex> state = %{confirmed_count: 15, waitlist_count: 0, fields_available: 1}
      iex> Specification.is_satisfied_by(odd, state)
      true
  """
  @spec not_spec(t) :: t
  def not_spec(spec)
end
