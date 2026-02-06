defmodule Sideout.SchedulingShareLinkTest do
  use Sideout.DataCase

  alias Sideout.{Scheduling, Accounts}
  alias Sideout.Scheduling.Session

  setup do
    # Create a test user
    {:ok, user} = 
      Accounts.register_user(%{
        email: "test@example.com",
        password: "TestPass123!",
        password_confirmation: "TestPass123!"
      })

    {:ok, user: user}
  end

  describe "create_session/2 with share tokens" do
    test "automatically generates share_token on session creation", %{user: user} do
      session_attrs = %{
        date: Date.utc_today() |> Date.add(7),
        start_time: ~T[18:00:00],
        end_time: ~T[20:00:00],
        fields_available: 1,
        capacity_constraints: "max_15",
        cancellation_deadline_hours: 24,
        status: :scheduled
      }

      {:ok, session} = Scheduling.create_session(user, session_attrs)

      assert session.share_token != nil
      assert String.length(session.share_token) == 21
    end

    test "generates unique share tokens for multiple sessions", %{user: user} do
      base_attrs = %{
        start_time: ~T[18:00:00],
        end_time: ~T[20:00:00],
        fields_available: 1,
        capacity_constraints: "max_15",
        cancellation_deadline_hours: 24,
        status: :scheduled
      }

      # Create 5 sessions
      sessions = 
        for i <- 1..5 do
          attrs = Map.put(base_attrs, :date, Date.utc_today() |> Date.add(i))
          {:ok, session} = Scheduling.create_session(user, attrs)
          session
        end

      tokens = Enum.map(sessions, & &1.share_token)
      unique_tokens = Enum.uniq(tokens)

      # All tokens should be unique
      assert length(unique_tokens) == 5
    end
  end

  describe "get_session_by_share_token/2" do
    test "returns session with valid token", %{user: user} do
      # Create a session
      {:ok, session} = 
        Scheduling.create_session(user, %{
          date: Date.utc_today() |> Date.add(7),
          start_time: ~T[18:00:00],
          end_time: ~T[20:00:00],
          fields_available: 1,
          capacity_constraints: "max_15",
          cancellation_deadline_hours: 24,
          status: :scheduled
        })

      # Retrieve by share token
      found_session = Scheduling.get_session_by_share_token(session.share_token)

      assert found_session != nil
      assert found_session.id == session.id
      assert found_session.share_token == session.share_token
    end

    test "returns nil for invalid token" do
      result = Scheduling.get_session_by_share_token("invalid_token_here_xx")
      assert result == nil
    end

    test "returns nil for malformed token" do
      result = Scheduling.get_session_by_share_token("short")
      assert result == nil
    end

    test "returns nil for nil token" do
      result = Scheduling.get_session_by_share_token(nil)
      assert result == nil
    end

    test "preloads necessary associations", %{user: user} do
      # Create a session with template
      {:ok, template} = 
        Scheduling.create_session_template(user, %{
          name: "Test Template",
          day_of_week: :monday,
          start_time: ~T[18:00:00],
          end_time: ~T[20:00:00],
          skill_level: :intermediate,
          fields_available: 1,
          capacity_constraints: "max_15",
          cancellation_deadline_hours: 24,
          active: true
        })

      {:ok, session} = 
        Scheduling.create_session_from_template(template, Date.utc_today() |> Date.add(7))

      # Get by share token with preload option
      found_session = Scheduling.get_session_by_share_token(session.share_token, preload: [:session_template])

      assert found_session.session_template != nil
      assert found_session.session_template.name == "Test Template"
    end
  end

  describe "share_token_valid?/1" do
    test "returns true for upcoming scheduled session", %{user: user} do
      {:ok, session} = 
        Scheduling.create_session(user, %{
          date: Date.utc_today() |> Date.add(7),
          start_time: ~T[18:00:00],
          end_time: ~T[20:00:00],
          fields_available: 1,
          capacity_constraints: "max_15",
          cancellation_deadline_hours: 24,
          status: :scheduled
        })

      assert Scheduling.share_token_valid?(session) == true
    end

    test "returns false for cancelled session", %{user: user} do
      {:ok, session} = 
        Scheduling.create_session(user, %{
          date: Date.utc_today() |> Date.add(7),
          start_time: ~T[18:00:00],
          end_time: ~T[20:00:00],
          fields_available: 1,
          capacity_constraints: "max_15",
          cancellation_deadline_hours: 24,
          status: :cancelled
        })

      assert Scheduling.share_token_valid?(session) == false
    end

    test "returns false for completed session", %{user: user} do
      {:ok, session} = 
        Scheduling.create_session(user, %{
          date: Date.utc_today() |> Date.add(-7),
          start_time: ~T[18:00:00],
          end_time: ~T[20:00:00],
          fields_available: 1,
          capacity_constraints: "max_15",
          cancellation_deadline_hours: 24,
          status: :completed
        })

      assert Scheduling.share_token_valid?(session) == false
    end

    test "returns false for past date session", %{user: user} do
      # Note: Can't test past date sessions because schema validation prevents creating them
      # This would need to be tested at a lower level by bypassing changeset validation
      # or by manually updating the database
      
      # Instead, test by getting a session and checking the validation logic
      {:ok, session} = 
        Scheduling.create_session(user, %{
          date: Date.utc_today() |> Date.add(7),
          start_time: ~T[18:00:00],
          end_time: ~T[20:00:00],
          fields_available: 1,
          capacity_constraints: "max_15",
          cancellation_deadline_hours: 24,
          status: :scheduled
        })

      # Manually set the date to the past to test validation
      past_session = %{session | date: Date.utc_today() |> Date.add(-7)}
      
      assert Scheduling.share_token_valid?(past_session) == false
    end
  end

  describe "generate_unique_share_token/0" do
    test "generates a valid share token" do
      token = Scheduling.generate_unique_share_token()

      assert token != nil
      assert String.length(token) == 21
    end

    test "generates unique tokens on multiple calls" do
      tokens = for _ <- 1..10, do: Scheduling.generate_unique_share_token()
      unique_tokens = Enum.uniq(tokens)

      assert length(unique_tokens) == 10
    end
  end
end
