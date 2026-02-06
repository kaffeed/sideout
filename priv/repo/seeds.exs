# Script for populating the database with realistic test data
#
# Run with: mix run priv/repo/seeds.exs

alias Sideout.Repo
alias Sideout.Accounts.User
alias Sideout.Scheduling.{Player, SessionTemplate, Session, Registration}

require Logger

Logger.info("Starting database seeding...")

# Clear existing data (in correct order to avoid FK constraint violations)
Logger.info("Clearing existing scheduling data...")
Repo.delete_all(Registration)
Repo.delete_all(Session)
Repo.delete_all(SessionTemplate)
Repo.delete_all(Player)
# Keep existing users

# Helper functions
random_email = fn name ->
  name
  |> String.downcase()
  |> String.replace(" ", ".")
  |> then(&"#{&1}@example.com")
end

random_phone = fn ->
  "555-#{Enum.random(100..999)}-#{Enum.random(1000..9999)}"
end

days_ago = fn days ->
  Date.utc_today() |> Date.add(-days)
end

days_from_now = fn days ->
  Date.utc_today() |> Date.add(days)
end

# ============================================================================
# TRAINERS
# ============================================================================

Logger.info("Creating trainers...")

trainer_1 = 
  case Repo.get_by(User, email: "coach.mike@sideout.com") do
    nil ->
      %User{}
      |> User.registration_changeset(%{
        email: "coach.mike@sideout.com",
        password: "password1234",
        password_confirmation: "password1234"
      })
      |> Repo.insert!()
    user -> user
  end

trainer_2 = 
  case Repo.get_by(User, email: "coach.sarah@sideout.com") do
    nil ->
      %User{}
      |> User.registration_changeset(%{
        email: "coach.sarah@sideout.com",
        password: "password1234",
        password_confirmation: "password1234"
      })
      |> Repo.insert!()
    user -> user
  end

trainer_3 = 
  case Repo.get_by(User, email: "coach.alex@sideout.com") do
    nil ->
      %User{}
      |> User.registration_changeset(%{
        email: "coach.alex@sideout.com",
        password: "password1234",
        password_confirmation: "password1234"
      })
      |> Repo.insert!()
    user -> user
  end

Logger.info("Created #{3} trainers")

# ============================================================================
# PLAYERS
# ============================================================================

Logger.info("Creating players...")

# 10 regular players (high attendance, reliable)
regular_players = 
  for i <- 1..10 do
    name = [
      "Emma Wilson", "Liam Johnson", "Olivia Martinez", "Noah Davis",
      "Ava Brown", "Ethan Anderson", "Sophia Garcia", "Mason Taylor",
      "Isabella Thomas", "William Moore"
    ] |> Enum.at(i - 1)

    %Player{}
    |> Player.changeset(%{
      name: name,
      email: random_email.(name),
      phone: if(rem(i, 2) == 0, do: random_phone.(), else: nil),
      total_attendance: Enum.random(20..35),
      total_registrations: Enum.random(25..40),
      total_no_shows: Enum.random(0..1),
      total_waitlists: Enum.random(2..5),
      last_attendance_date: days_ago.(Enum.random(1..7))
    })
    |> Repo.insert!()
  end

# 10 occasional players (medium attendance)
occasional_players = 
  for i <- 1..10 do
    name = [
      "James White", "Charlotte Lee", "Benjamin Harris", "Amelia Clark",
      "Lucas Lewis", "Mia Robinson", "Henry Walker", "Evelyn Young",
      "Alexander Hall", "Harper Allen"
    ] |> Enum.at(i - 1)

    %Player{}
    |> Player.changeset(%{
      name: name,
      email: random_email.(name),
      phone: if(rem(i, 3) == 0, do: random_phone.(), else: nil),
      total_attendance: Enum.random(8..15),
      total_registrations: Enum.random(12..20),
      total_no_shows: Enum.random(1..3),
      total_waitlists: Enum.random(3..8),
      last_attendance_date: days_ago.(Enum.random(10..21))
    })
    |> Repo.insert!()
  end

# 10 new players (little or no history)
new_players = 
  for i <- 1..10 do
    name = [
      "Daniel King", "Abigail Wright", "Michael Lopez", "Emily Hill",
      "Elijah Scott", "Elizabeth Green", "Sebastian Adams", "Sofia Baker",
      "Jack Nelson", "Avery Carter"
    ] |> Enum.at(i - 1)

    %Player{}
    |> Player.changeset(%{
      name: name,
      email: if(rem(i, 2) == 0, do: random_email.(name), else: nil),
      phone: if(rem(i, 3) == 0, do: random_phone.(), else: nil),
      total_attendance: Enum.random(0..3),
      total_registrations: Enum.random(0..5),
      total_no_shows: 0,
      total_waitlists: Enum.random(0..2),
      last_attendance_date: if(Enum.random(1..3) == 1, do: days_ago.(Enum.random(1..5)), else: nil)
    })
    |> Repo.insert!()
  end

all_players = regular_players ++ occasional_players ++ new_players
Logger.info("Created #{length(all_players)} players")

# ============================================================================
# SESSION TEMPLATES
# ============================================================================

Logger.info("Creating session templates...")

template_1 = 
  %SessionTemplate{}
  |> SessionTemplate.changeset(%{
    name: "Monday Beginner",
    day_of_week: :monday,
    start_time: ~T[18:00:00],
    end_time: ~T[20:00:00],
    skill_level: :beginner,
    fields_available: 1,
    capacity_constraints: "max_15,min_8",
    cancellation_deadline_hours: 24,
    active: true,
    user_id: trainer_3.id
  })
  |> Repo.insert!()

template_2 = 
  %SessionTemplate{}
  |> SessionTemplate.changeset(%{
    name: "Monday Advanced",
    day_of_week: :monday,
    start_time: ~T[20:00:00],
    end_time: ~T[22:00:00],
    skill_level: :advanced,
    fields_available: 1,
    capacity_constraints: "max_18,min_12,even",
    cancellation_deadline_hours: 48,
    active: true,
    user_id: trainer_1.id
  })
  |> Repo.insert!()

template_3 = 
  %SessionTemplate{}
  |> SessionTemplate.changeset(%{
    name: "Wednesday Intermediate",
    day_of_week: :wednesday,
    start_time: ~T[19:00:00],
    end_time: ~T[21:00:00],
    skill_level: :intermediate,
    fields_available: 2,
    capacity_constraints: "per_field_9",
    cancellation_deadline_hours: 24,
    active: true,
    user_id: trainer_2.id
  })
  |> Repo.insert!()

template_4 = 
  %SessionTemplate{}
  |> SessionTemplate.changeset(%{
    name: "Friday Mixed",
    day_of_week: :friday,
    start_time: ~T[18:00:00],
    end_time: ~T[20:00:00],
    skill_level: :mixed,
    fields_available: 1,
    capacity_constraints: "max_18,divisible_by_6",
    cancellation_deadline_hours: 12,
    active: true,
    user_id: trainer_1.id
  })
  |> Repo.insert!()

template_5 = 
  %SessionTemplate{}
  |> SessionTemplate.changeset(%{
    name: "Saturday Open",
    day_of_week: :saturday,
    start_time: ~T[10:00:00],
    end_time: ~T[12:00:00],
    skill_level: :mixed,
    fields_available: 2,
    capacity_constraints: "max_20",
    cancellation_deadline_hours: 24,
    active: true,
    user_id: trainer_2.id
  })
  |> Repo.insert!()

Logger.info("Created #{5} session templates")

# ============================================================================
# SESSIONS
# ============================================================================

Logger.info("Creating sessions...")

# Note: share_token is auto-generated by Session.changeset/2 for each session
# using the ShareToken module. No need to specify it explicitly here.

sessions = []

# Past session (1 week ago - Monday Advanced)
past_session = 
  %Session{}
  |> Session.changeset(%{
    date: days_ago.(7),
    start_time: ~T[20:00:00],
    end_time: ~T[22:00:00],
    fields_available: 1,
    capacity_constraints: "max_18,min_12,even",
    cancellation_deadline_hours: 48,
    status: :completed,
    session_template_id: template_2.id,
    user_id: trainer_1.id
  })
  |> Repo.insert!()

sessions = [past_session | sessions]

# This week's sessions
monday_beginner_this_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(1),
    start_time: ~T[18:00:00],
    end_time: ~T[20:00:00],
    fields_available: 1,
    capacity_constraints: "max_15,min_8",
    cancellation_deadline_hours: 24,
    status: :scheduled,
    session_template_id: template_1.id,
    user_id: trainer_3.id
  })
  |> Repo.insert!()

sessions = [monday_beginner_this_week | sessions]

monday_advanced_this_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(1),
    start_time: ~T[20:00:00],
    end_time: ~T[22:00:00],
    fields_available: 1,
    capacity_constraints: "max_18,min_12,even",
    cancellation_deadline_hours: 48,
    status: :scheduled,
    session_template_id: template_2.id,
    user_id: trainer_1.id
  })
  |> Repo.insert!()

sessions = [monday_advanced_this_week | sessions]

wednesday_this_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(3),
    start_time: ~T[19:00:00],
    end_time: ~T[21:00:00],
    fields_available: 2,
    capacity_constraints: "per_field_9",
    cancellation_deadline_hours: 24,
    status: :scheduled,
    session_template_id: template_3.id,
    user_id: trainer_2.id
  })
  |> Repo.insert!()

sessions = [wednesday_this_week | sessions]

friday_this_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(5),
    start_time: ~T[18:00:00],
    end_time: ~T[20:00:00],
    fields_available: 1,
    capacity_constraints: "max_18,divisible_by_6",
    cancellation_deadline_hours: 12,
    status: :scheduled,
    session_template_id: template_4.id,
    user_id: trainer_1.id
  })
  |> Repo.insert!()

sessions = [friday_this_week | sessions]

saturday_this_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(6),
    start_time: ~T[10:00:00],
    end_time: ~T[12:00:00],
    fields_available: 2,
    capacity_constraints: "max_20",
    cancellation_deadline_hours: 24,
    status: :scheduled,
    session_template_id: template_5.id,
    user_id: trainer_2.id
  })
  |> Repo.insert!()

sessions = [saturday_this_week | sessions]

# Next week's sessions
monday_beginner_next_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(8),
    start_time: ~T[18:00:00],
    end_time: ~T[20:00:00],
    fields_available: 1,
    capacity_constraints: "max_15,min_8",
    cancellation_deadline_hours: 24,
    status: :scheduled,
    session_template_id: template_1.id,
    user_id: trainer_3.id
  })
  |> Repo.insert!()

sessions = [monday_beginner_next_week | sessions]

monday_advanced_next_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(8),
    start_time: ~T[20:00:00],
    end_time: ~T[22:00:00],
    fields_available: 1,
    capacity_constraints: "max_18,min_12,even",
    cancellation_deadline_hours: 48,
    status: :scheduled,
    session_template_id: template_2.id,
    user_id: trainer_1.id
  })
  |> Repo.insert!()

sessions = [monday_advanced_next_week | sessions]

wednesday_next_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(10),
    start_time: ~T[19:00:00],
    end_time: ~T[21:00:00],
    fields_available: 2,
    capacity_constraints: "per_field_9",
    cancellation_deadline_hours: 24,
    status: :scheduled,
    session_template_id: template_3.id,
    user_id: trainer_2.id
  })
  |> Repo.insert!()

sessions = [wednesday_next_week | sessions]

friday_next_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(12),
    start_time: ~T[18:00:00],
    end_time: ~T[20:00:00],
    fields_available: 1,
    capacity_constraints: "max_18,divisible_by_6",
    cancellation_deadline_hours: 12,
    status: :scheduled,
    session_template_id: template_4.id,
    user_id: trainer_1.id
  })
  |> Repo.insert!()

sessions = [friday_next_week | sessions]

saturday_next_week = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(13),
    start_time: ~T[10:00:00],
    end_time: ~T[12:00:00],
    fields_available: 2,
    capacity_constraints: "max_20",
    cancellation_deadline_hours: 24,
    status: :scheduled,
    session_template_id: template_5.id,
    user_id: trainer_2.id
  })
  |> Repo.insert!()

sessions = [saturday_next_week | sessions]

# One-off special session (no template)
special_session = 
  %Session{}
  |> Session.changeset(%{
    date: days_from_now.(14),
    start_time: ~T[14:00:00],
    end_time: ~T[16:00:00],
    fields_available: 1,
    capacity_constraints: "max_12",
    cancellation_deadline_hours: 72,
    notes: "Special tournament prep session",
    status: :scheduled,
    user_id: trainer_1.id
  })
  |> Repo.insert!()

sessions = [special_session | sessions]

Logger.info("Created #{length(sessions)} sessions")

# Verify all sessions have share tokens
sessions_without_tokens = Enum.filter(sessions, fn s -> is_nil(s.share_token) end)
if length(sessions_without_tokens) > 0 do
  Logger.warning("Warning: #{length(sessions_without_tokens)} sessions created without share tokens!")
else
  Logger.info("✓ All sessions have share tokens for public signup links")
end

# ============================================================================
# REGISTRATIONS
# ============================================================================

Logger.info("Creating registrations...")

# Helper to create registration
create_registration = fn session, player, status, opts ->
  registered_at = Keyword.get(opts, :registered_at, DateTime.utc_now())
  priority_score = Keyword.get(opts, :priority_score)
  position = Keyword.get(opts, :position)
  
  %Registration{}
  |> Registration.changeset(%{
    session_id: session.id,
    player_id: player.id,
    status: status,
    registered_at: registered_at,
    priority_score: priority_score,
    position: position,
    cancellation_token: :crypto.strong_rand_bytes(16) |> Base.url_encode64()
  })
  |> Repo.insert!()
end

# Past session - all attended
for player <- Enum.take(regular_players, 16) do
  create_registration.(past_session, player, :attended, [])
end

# Monday Beginner This Week - Almost full (13/15), 2 waitlisted
for {player, index} <- Enum.with_index(Enum.take(all_players, 13)) do
  create_registration.(monday_beginner_this_week, player, :confirmed, [position: index + 1])
end

for {player, index} <- Enum.with_index(Enum.slice(all_players, 13, 2)) do
  create_registration.(monday_beginner_this_week, player, :waitlisted, [
    priority_score: Decimal.from_float(120.0 - index * 5),
    position: index + 1
  ])
end

# Monday Advanced This Week - Full (18/18), 5 waitlisted
for {player, index} <- Enum.with_index(Enum.take(regular_players ++ occasional_players, 18)) do
  create_registration.(monday_advanced_this_week, player, :confirmed, [position: index + 1])
end

for {player, index} <- Enum.with_index(Enum.slice(all_players, 18, 5)) do
  create_registration.(monday_advanced_this_week, player, :waitlisted, [
    priority_score: Decimal.from_float(135.0 - index * 8),
    position: index + 1
  ])
end

# Wednesday This Week - Good capacity (14/18 with 2 fields)
for {player, index} <- Enum.with_index(Enum.take(all_players, 14)) do
  create_registration.(wednesday_this_week, player, :confirmed, [position: index + 1])
end

# Friday This Week - Needs to be divisible by 6, currently 12/18
for {player, index} <- Enum.with_index(Enum.take(regular_players, 12)) do
  create_registration.(friday_this_week, player, :confirmed, [position: index + 1])
end

# Saturday This Week - Partially filled (16/20)
for {player, index} <- Enum.with_index(Enum.take(all_players, 16)) do
  create_registration.(saturday_this_week, player, :confirmed, [position: index + 1])
end

# Next week sessions - lighter registrations
for {player, index} <- Enum.with_index(Enum.take(regular_players, 8)) do
  create_registration.(monday_beginner_next_week, player, :confirmed, [position: index + 1])
end

for {player, index} <- Enum.with_index(Enum.take(occasional_players, 10)) do
  create_registration.(monday_advanced_next_week, player, :confirmed, [position: index + 1])
end

for {player, index} <- Enum.with_index(Enum.take(all_players, 12)) do
  create_registration.(wednesday_next_week, player, :confirmed, [position: index + 1])
end

# Special session - just a few early birds
for {player, index} <- Enum.with_index(Enum.take(regular_players, 5)) do
  create_registration.(special_session, player, :confirmed, [position: index + 1])
end

registration_count = Repo.aggregate(Registration, :count)
Logger.info("Created #{registration_count} registrations")

# ============================================================================
# SUMMARY
# ============================================================================

Logger.info("""

==============================================================================
DATABASE SEEDED SUCCESSFULLY!
==============================================================================

Summary:
  - Trainers: 3
    * coach.mike@sideout.com (password: password1234)
    * coach.sarah@sideout.com (password: password1234)
    * coach.alex@sideout.com (password: password1234)
    
  - Players: #{length(all_players)}
    * Regular players: #{length(regular_players)} (high attendance)
    * Occasional players: #{length(occasional_players)} (medium attendance)
    * New players: #{length(new_players)} (little/no history)
    
  - Session Templates: 5
    * Monday Beginner (max_15,min_8)
    * Monday Advanced (max_18,min_12,even)
    * Wednesday Intermediate (per_field_9)
    * Friday Mixed (max_18,divisible_by_6)
    * Saturday Open (max_20)
    
  - Sessions: #{length(sessions)}
    * Past: 1 (completed)
    * This week: 5 (scheduled)
    * Next week: 5 (scheduled)
    * Special: 1 (one-off)
    
  - Registrations: #{registration_count}
    * Past session: 16 attended
    * Upcoming sessions: Mix of confirmed and waitlisted
    * Some sessions at capacity with waitlists

Test the constraint system:
  - Monday Beginner: 13/15 confirmed, 2 waitlisted (can add 2 more)
  - Monday Advanced: 18/18 confirmed, 5 waitlisted (FULL - even constraint)
  - Friday Mixed: 12/18 (divisible by 6 constraint working)

==============================================================================
""")
