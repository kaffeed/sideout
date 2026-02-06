# Test script to verify constraint system using Pure Specification Pattern
alias Sideout.{Repo, Scheduling}
alias Sideout.Scheduling.{Specification, Constraints}

IO.puts("\n=== Testing Constraint System (Pure Specification Pattern) ===\n")

# Get Monday Beginner This Week session (13/15 confirmed, 2 waitlisted)
sessions = Scheduling.list_upcoming_sessions()

monday_beginner =
  Enum.find(sessions, fn s ->
    String.contains?(s.capacity_constraints, "max_15,min_8")
  end)

if monday_beginner do
  IO.puts("=== Monday Beginner (max_15,min_8) ===")
  IO.puts("Date: #{monday_beginner.date}")
  IO.puts("Constraints: #{monday_beginner.capacity_constraints}")

  status = Scheduling.get_capacity_status(monday_beginner)
  IO.puts("\nCapacity Status:")
  IO.puts("  Confirmed: #{status.confirmed}")
  IO.puts("  Waitlist: #{status.waitlist}")
  IO.puts("  Can add player?: #{status.can_add_player}")
  IO.puts("  Constraints satisfied?: #{status.constraints_satisfied}")
  IO.puts("  Description: #{status.description}")
end

# Get Monday Advanced session (18/18 confirmed, 5 waitlisted)
monday_advanced =
  Enum.find(sessions, fn s ->
    String.contains?(s.capacity_constraints, "max_18,min_12,even")
  end)

if monday_advanced do
  IO.puts("\n=== Monday Advanced (max_18,min_12,even) ===")
  IO.puts("Date: #{monday_advanced.date}")
  IO.puts("Constraints: #{monday_advanced.capacity_constraints}")

  status = Scheduling.get_capacity_status(monday_advanced)
  IO.puts("\nCapacity Status:")
  IO.puts("  Confirmed: #{status.confirmed}")
  IO.puts("  Waitlist: #{status.waitlist}")
  IO.puts("  Can add player?: #{status.can_add_player}")
  IO.puts("  Constraints satisfied?: #{status.constraints_satisfied}")
  IO.puts("  Description: #{status.description}")

  unless Enum.empty?(status.unsatisfied_constraints) do
    IO.puts("\n  Unsatisfied constraints:")

    for constraint <- status.unsatisfied_constraints do
      IO.puts("    - #{Specification.description(constraint)}")
    end
  end
end

# Get Friday session (divisible by 6 constraint)
friday_session =
  Enum.find(sessions, fn s ->
    String.contains?(s.capacity_constraints, "divisible_by_6")
  end)

if friday_session do
  IO.puts("\n=== Friday Mixed (max_18,divisible_by_6) ===")
  IO.puts("Date: #{friday_session.date}")
  IO.puts("Constraints: #{friday_session.capacity_constraints}")

  status = Scheduling.get_capacity_status(friday_session)
  IO.puts("\nCapacity Status:")
  IO.puts("  Confirmed: #{status.confirmed}")
  IO.puts("  Waitlist: #{status.waitlist}")
  IO.puts("  Can add player?: #{status.can_add_player}")
  IO.puts("  Constraints satisfied?: #{status.constraints_satisfied}")
  IO.puts("  Description: #{status.description}")
end

IO.puts("\n=== Testing Programmatic Composition (Pure Pattern) ===\n")
# Demonstrate the pure Specification pattern's composability
max_18 = %Constraints.MaxCapacityConstraint{value: 18}
min_12 = %Constraints.MinCapacityConstraint{value: 12}
even = %Constraints.EvenNumberConstraint{}

# Test basic AND composition
and_spec = Specification.and_spec(max_18, min_12)
state = %{confirmed_count: 15, waitlist_count: 0, fields_available: 1}

IO.puts("Testing: (max_18 AND min_12)")
IO.puts("  State: 15 confirmed")
IO.puts("  Satisfied?: #{Specification.is_satisfied_by(and_spec, state)}")
IO.puts("  Description: #{Specification.description(and_spec)}")

# Test OR composition
or_spec =
  Specification.or_spec(
    %Constraints.MaxCapacityConstraint{value: 10},
    %Constraints.PerFieldConstraint{players_per_field: 9}
  )

state2 = %{confirmed_count: 15, waitlist_count: 0, fields_available: 2}

IO.puts("\nTesting: (max_10 OR per_field_9)")
IO.puts("  State: 15 confirmed, 2 fields")
IO.puts("  Satisfied?: #{Specification.is_satisfied_by(or_spec, state2)}")
IO.puts("  Description: #{Specification.description(or_spec)}")

# Test NOT composition
not_even = Specification.not_spec(even)
state3 = %{confirmed_count: 13, waitlist_count: 0, fields_available: 1}

IO.puts("\nTesting: NOT(even)")
IO.puts("  State: 13 confirmed (odd)")
IO.puts("  Satisfied?: #{Specification.is_satisfied_by(not_even, state3)}")
IO.puts("  Description: #{Specification.description(not_even)}")

# Test complex composition: (max_18 AND even) OR min_12
complex =
  max_18
  |> Specification.and_spec(even)
  |> Specification.or_spec(min_12)

state4 = %{confirmed_count: 11, waitlist_count: 0, fields_available: 1}

IO.puts("\nTesting: ((max_18 AND even) OR min_12)")
IO.puts("  State: 11 confirmed (odd, < 12)")
IO.puts("  Satisfied?: #{Specification.is_satisfied_by(complex, state4)}")
IO.puts("  Description: #{Specification.description(complex)}")

# Test fluent interface / pipe-based composition
IO.puts("\n=== Testing Fluent/Pipe-based Composition ===\n")

fluent_spec =
  max_18
  |> Specification.and_spec(min_12)
  |> Specification.and_spec(even)

state5 = %{confirmed_count: 16, waitlist_count: 0, fields_available: 1}

IO.puts("Testing: max_18 |> and(min_12) |> and(even)")
IO.puts("  State: 16 confirmed (even, within range)")
IO.puts("  Satisfied?: #{Specification.is_satisfied_by(fluent_spec, state5)}")

IO.puts("  Description: #{Specification.description(fluent_spec)}")

IO.puts("\n=== All Tests Complete! ===\n")
