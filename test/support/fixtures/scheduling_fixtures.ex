defmodule Sideout.SchedulingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Sideout.Scheduling` context.
  """

  alias Sideout.{Scheduling, Repo}
  alias Sideout.AccountsFixtures

  @doc """
  Generate a unique player name.
  """
  def unique_player_name, do: "player_#{System.unique_integer()}"
  def unique_player_email, do: "player_#{System.unique_integer()}@example.com"

  @doc """
  Generate valid player attributes.
  """
  def valid_player_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_player_name(),
      email: unique_player_email(),
      phone: "+1 (555) 123-4567"
    })
  end

  @doc """
  Generate a player.
  """
  def player_fixture(attrs \\ %{}) do
    {:ok, player} =
      attrs
      |> valid_player_attributes()
      |> Scheduling.create_player()

    player
  end

  @doc """
  Generate valid session template attributes.
  """
  def valid_template_attributes(_user, attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Template #{System.unique_integer()}",
      "day_of_week" => :monday,
      "start_time" => ~T[18:00:00],
      "end_time" => ~T[20:00:00],
      "skill_level" => :intermediate,
      "fields_available" => 2,
      "capacity_constraints" => "max_18,min_12",
      "cancellation_deadline_hours" => 24,
      "active" => true
    })
  end

  @doc """
  Generate a session template.
  """
  def template_fixture(user \\ nil, attrs \\ %{}) do
    user = user || AccountsFixtures.user_fixture()

    {:ok, template} =
      user
      |> valid_template_attributes(attrs)
      |> then(&Scheduling.create_session_template(user, &1))

    template
  end

  @doc """
  Generate valid session attributes.
  """
  def valid_session_attributes(_user, attrs \\ %{}) do
    # Default to tomorrow to pass future date validation
    tomorrow = Date.utc_today() |> Date.add(1)

    Enum.into(attrs, %{
      "date" => tomorrow,
      "start_time" => ~T[18:00:00],
      "end_time" => ~T[20:00:00],
      "fields_available" => 2,
      "capacity_constraints" => "max_18,min_12",
      "cancellation_deadline_hours" => 24,
      "status" => :scheduled
    })
  end

  @doc """
  Generate a session.
  """
  def session_fixture(user \\ nil, attrs \\ %{}) do
    user = user || AccountsFixtures.user_fixture()

    {:ok, session} =
      user
      |> valid_session_attributes(attrs)
      |> then(&Scheduling.create_session(user, &1))

    session
  end

  @doc """
  Generate a session with registrations.
  """
  def session_with_registrations_fixture(user \\ nil, num_confirmed \\ 5, num_waitlisted \\ 2) do
    user = user || AccountsFixtures.user_fixture()
    session = session_fixture(user)

    # Create confirmed registrations
    confirmed_players =
      for _i <- 1..num_confirmed do
        player = player_fixture()
        {:ok, registration} = Scheduling.register_player(session, player)
        {player, registration}
      end

    # Create waitlisted registrations
    waitlisted_players =
      if num_waitlisted > 0 do
        for _i <- 1..num_waitlisted do
          player = player_fixture()
          {:ok, registration} = Scheduling.register_player(session, player)
          {player, registration}
        end
      else
        []
      end

    session = Repo.preload(session, [registrations: :player], force: true)

    %{
      session: session,
      user: user,
      confirmed: confirmed_players,
      waitlisted: waitlisted_players
    }
  end

  @doc """
  Generate a registration.
  """
  def registration_fixture(session \\ nil, player \\ nil, _attrs \\ %{}) do
    session = session || session_fixture()
    player = player || player_fixture()

    {:ok, registration} = Scheduling.register_player(session, player)
    registration
  end

  @doc """
  Create multiple players with different attendance histories.
  """
  def players_with_history_fixture do
    # High attendance player (attended 20, no-showed 1)
    high_attendance =
      player_fixture(%{
        total_attendance: 20,
        total_registrations: 21,
        total_no_shows: 1,
        last_attendance_date: Date.utc_today() |> Date.add(-1)
      })

    # Medium attendance player (attended 10, no-showed 3)
    medium_attendance =
      player_fixture(%{
        total_attendance: 10,
        total_registrations: 13,
        total_no_shows: 3,
        last_attendance_date: Date.utc_today() |> Date.add(-7)
      })

    # Low attendance player (attended 2, no-showed 5)
    low_attendance =
      player_fixture(%{
        total_attendance: 2,
        total_registrations: 7,
        total_no_shows: 5,
        last_attendance_date: Date.utc_today() |> Date.add(-30)
      })

    # New player (no history)
    new_player = player_fixture()

    %{
      high: high_attendance,
      medium: medium_attendance,
      low: low_attendance,
      new: new_player
    }
  end
end
