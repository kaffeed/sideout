defmodule Sideout.Scheduling do
  @moduledoc """
  The Scheduling context.
  Manages players, session templates, sessions, and registrations.
  """

  import Ecto.Query, warn: false
  alias Sideout.Repo

  alias Sideout.Scheduling.{
    Player,
    SessionTemplate,
    Session,
    Registration,
    ConstraintResolver,
    RegistrationToken,
    PriorityCalculator,
    ShareToken
  }

  ## Player Management

  @doc """
  Returns the list of players.

  ## Options
    * `:preload` - List of associations to preload
    * `:order_by` - Field to order by (default: :name)
    * `:search` - Search term for name

  ## Examples

      iex> list_players()
      [%Player{}, ...]

      iex> list_players(preload: [:registrations])
      [%Player{registrations: [...]}, ...]

  """
  def list_players(opts \\ []) do
    preload = Keyword.get(opts, :preload, [])
    order_by = Keyword.get(opts, :order_by, :name)
    search = Keyword.get(opts, :search)

    Player
    |> maybe_search_players(search)
    |> order_by(^order_by)
    |> Repo.all()
    |> Repo.preload(preload)
  end

  defp maybe_search_players(query, nil), do: query

  defp maybe_search_players(query, search) do
    search_term = "%#{search}%"
    where(query, [p], ilike(p.name, ^search_term) or ilike(p.email, ^search_term))
  end

  @doc """
  Gets a single player.

  Raises `Ecto.NoResultsError` if the Player does not exist.

  ## Examples

      iex> get_player!(123)
      %Player{}

      iex> get_player!(456)
      ** (Ecto.NoResultsError)

  """
  def get_player!(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    Player
    |> Repo.get!(id)
    |> Repo.preload(preload)
  end

  @doc """
  Gets a player by name, or creates one if it doesn't exist.

  ## Examples

      iex> get_or_create_player_by_name("John Doe")
      {:ok, %Player{}}

  """
  def get_or_create_player_by_name(name, attrs \\ %{}) do
    case Repo.get_by(Player, name: name) do
      nil ->
        attrs = Map.put(attrs, "name", name)
        create_player(attrs)

      player ->
        {:ok, player}
    end
  end

  @doc """
  Creates a player.

  ## Examples

      iex> create_player(%{name: "John Doe"})
      {:ok, %Player{}}

      iex> create_player(%{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_player(attrs \\ %{}) do
    %Player{}
    |> Player.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a player.

  ## Examples

      iex> update_player(player, %{name: "Jane Doe"})
      {:ok, %Player{}}

      iex> update_player(player, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_player(%Player{} = player, attrs) do
    player
    |> Player.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a player.

  ## Examples

      iex> delete_player(player)
      {:ok, %Player{}}

      iex> delete_player(player)
      {:error, %Ecto.Changeset{}}

  """
  def delete_player(%Player{} = player) do
    Repo.delete(player)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking player changes.

  ## Examples

      iex> change_player(player)
      %Ecto.Changeset{data: %Player{}}

  """
  def change_player(%Player{} = player, attrs \\ %{}) do
    Player.changeset(player, attrs)
  end

  @doc """
  Gets player statistics including attendance rate and no-show rate.

  ## Examples

      iex> get_player_stats(player)
      %{
        attendance_rate: 85.5,
        no_show_rate: 5.2,
        total_sessions: 20,
        completed_sessions: 17
      }

  """
  def get_player_stats(%Player{} = player) do
    total_completed =
      Registration
      |> where(player_id: ^player.id)
      |> where([r], r.status in [:attended, :no_show])
      |> Repo.aggregate(:count, :id)

    attended =
      Registration
      |> where(player_id: ^player.id, status: :attended)
      |> Repo.aggregate(:count, :id)

    no_shows =
      Registration
      |> where(player_id: ^player.id, status: :no_show)
      |> Repo.aggregate(:count, :id)

    attendance_rate =
      if total_completed > 0 do
        Float.round(attended / total_completed * 100, 1)
      else
        0.0
      end

    no_show_rate =
      if total_completed > 0 do
        Float.round(no_shows / total_completed * 100, 1)
      else
        0.0
      end

    %{
      attendance_rate: attendance_rate,
      no_show_rate: no_show_rate,
      total_sessions: player.total_registrations,
      completed_sessions: total_completed,
      attended: attended,
      no_shows: no_shows
    }
  end

  @doc """
  Gets player's registration history with session details.

  ## Options
    * `:limit` - Number of registrations to return
    * `:status` - Filter by status (:all, :upcoming, :past)

  ## Examples

      iex> get_player_registration_history(player, limit: 10, status: :past)
      [%Registration{}, ...]

  """
  def get_player_registration_history(%Player{} = player, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status, :all)

    Registration
    |> where(player_id: ^player.id)
    |> join(:inner, [r], s in Session, on: r.session_id == s.id)
    |> maybe_filter_registration_status(status)
    |> order_by([r, s], desc: s.date)
    |> limit(^limit)
    |> preload(session: [:session_template])
    |> Repo.all()
  end

  defp maybe_filter_registration_status(query, :all), do: query

  defp maybe_filter_registration_status(query, :upcoming) do
    today = Date.utc_today()

    query
    |> where([r, s], s.date >= ^today)
    |> where([r], r.status in [:confirmed, :waitlisted])
  end

  defp maybe_filter_registration_status(query, :past) do
    today = Date.utc_today()

    query
    |> where([r, s], s.date < ^today)
  end

  @doc """
  Gets upcoming sessions for a player.

  ## Examples

      iex> get_player_upcoming_sessions(player)
      [%Registration{}, ...]

  """
  def get_player_upcoming_sessions(%Player{} = player) do
    today = Date.utc_today()

    Registration
    |> where(player_id: ^player.id)
    |> where([r], r.status in [:confirmed, :waitlisted])
    |> join(:inner, [r], s in Session, on: r.session_id == s.id)
    |> where([r, s], s.date >= ^today)
    |> order_by([r, s], asc: s.date)
    |> preload(session: [:session_template])
    |> Repo.all()
  end

  ## Session Template Management

  @doc """
  Returns the list of session templates for a user.

  ## Options
    * `:preload` - List of associations to preload
    * `:active_only` - Only return active templates (default: false)

  ## Examples

      iex> list_session_templates(user_id)
      [%SessionTemplate{}, ...]

  """
  def list_session_templates(user_id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])
    active_only = Keyword.get(opts, :active_only, false)

    SessionTemplate
    |> where(user_id: ^user_id)
    |> maybe_filter_active(active_only)
    |> order_by([st], [st.day_of_week, st.start_time])
    |> Repo.all()
    |> Repo.preload(preload)
  end

  defp maybe_filter_active(query, false), do: query
  defp maybe_filter_active(query, true), do: where(query, active: true)

  @doc """
  Gets a single session template.

  Raises `Ecto.NoResultsError` if the SessionTemplate does not exist.
  """
  def get_session_template!(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    SessionTemplate
    |> Repo.get!(id)
    |> Repo.preload(preload)
  end

  @doc """
  Creates a session template.
  """
  def create_session_template(user, attrs \\ %{}) do
    attrs = Map.put(attrs, "user_id", user.id)

    %SessionTemplate{}
    |> SessionTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session template.
  """
  def update_session_template(%SessionTemplate{} = template, attrs) do
    template
    |> SessionTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a session template.
  """
  def delete_session_template(%SessionTemplate{} = template) do
    Repo.delete(template)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session template changes.
  """
  def change_session_template(%SessionTemplate{} = template, attrs \\ %{}) do
    SessionTemplate.changeset(template, attrs)
  end

  ## Session Management

  @doc """
  Returns the list of sessions.

  ## Options
    * `:preload` - List of associations to preload
    * `:from_date` - Filter sessions from this date forward
    * `:to_date` - Filter sessions up to this date
    * `:status` - Filter by status
    * `:user_id` - Filter by trainer
    * `:skill_level` - Filter by skill level (via session_template)

  ## Examples

      iex> list_sessions()
      [%Session{}, ...]

      iex> list_sessions(from_date: ~D[2026-02-05], preload: [:registrations])
      [%Session{registrations: [...]}, ...]

  """
  def list_sessions(opts \\ []) do
    preload = Keyword.get(opts, :preload, [])
    from_date = Keyword.get(opts, :from_date)
    to_date = Keyword.get(opts, :to_date)
    status = Keyword.get(opts, :status)
    user_id = Keyword.get(opts, :user_id)
    skill_level = Keyword.get(opts, :skill_level)

    Session
    |> maybe_filter_from_date(from_date)
    |> maybe_filter_to_date(to_date)
    |> maybe_filter_status(status)
    |> maybe_filter_user_id(user_id)
    |> maybe_filter_skill_level(skill_level)
    |> order_by([s], [s.date, s.start_time])
    |> Repo.all()
    |> Repo.preload(preload)
  end

  defp maybe_filter_from_date(query, nil), do: query
  defp maybe_filter_from_date(query, date), do: where(query, [s], s.date >= ^date)

  defp maybe_filter_to_date(query, nil), do: query
  defp maybe_filter_to_date(query, date), do: where(query, [s], s.date <= ^date)

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, statuses) when is_list(statuses) do
    where(query, [s], s.status in ^statuses)
  end
  defp maybe_filter_status(query, status), do: where(query, [s], s.status == ^status)

  defp maybe_filter_user_id(query, nil), do: query
  defp maybe_filter_user_id(query, user_id), do: where(query, user_id: ^user_id)

  defp maybe_filter_skill_level(query, nil), do: query
  defp maybe_filter_skill_level(query, skill_level) do
    query
    |> join(:left, [s], st in assoc(s, :session_template))
    |> where([s, st], st.skill_level == ^skill_level)
  end

  @doc """
  Returns the list of upcoming sessions (from today forward).
  """
  def list_upcoming_sessions(opts \\ []) do
    opts = Keyword.put(opts, :from_date, Date.utc_today())
    list_sessions(opts)
  end

  @doc """
  Gets a single session.

  Raises `Ecto.NoResultsError` if the Session does not exist.
  """
  def get_session!(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    Session
    |> Repo.get!(id)
    |> Repo.preload(preload)
  end

  @doc """
  Creates a session.
  """
  def create_session(user, attrs \\ %{}) do
    attrs = 
      attrs
      |> Map.put("user_id", user.id)
      |> Map.put_new("share_token", generate_unique_share_token())

    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a session from a template with optional overrides.
  """
  def create_session_from_template(%SessionTemplate{} = template, date, overrides \\ %{}) do
    attrs =
      %{
        date: date,
        start_time: template.start_time,
        end_time: template.end_time,
        fields_available: template.fields_available,
        capacity_constraints: template.capacity_constraints,
        cancellation_deadline_hours: template.cancellation_deadline_hours,
        session_template_id: template.id,
        user_id: template.user_id,
        share_token: generate_unique_share_token()
      }
      |> Map.merge(overrides)

    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session.
  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Cancels a session with a reason.
  """
  def cancel_session(%Session{} = session, reason \\ nil) do
    attrs = %{"status" => :cancelled, "notes" => reason}
    update_session(session, attrs)
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.
  """
  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  @doc """
  Generates a unique share token for a session.
  Recursively generates until a unique token is found.
  """
  def generate_unique_share_token do
    token = ShareToken.generate()

    case Repo.get_by(Session, share_token: token) do
      nil -> token
      _session -> generate_unique_share_token()
    end
  end

  @doc """
  Gets a session by its share token.
  Returns nil if the token is invalid, session doesn't exist, or session is expired/cancelled.

  ## Options
    * `:preload` - List of associations to preload

  ## Examples

      iex> get_session_by_share_token("valid_token_123")
      %Session{}

      iex> get_session_by_share_token("invalid_token")
      nil

  """
  def get_session_by_share_token(token, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    if ShareToken.valid?(token) do
      Session
      |> Repo.get_by(share_token: token)
      |> case do
        nil -> nil
        session ->
          session = Repo.preload(session, preload)
          if share_token_valid?(session), do: session, else: nil
      end
    else
      nil
    end
  end

  @doc """
  Checks if a session's share token is still valid.
  A share token is valid if the session is scheduled and the session date hasn't passed.

  ## Examples

      iex> share_token_valid?(session)
      true

      iex> share_token_valid?(cancelled_session)
      false

  """
  def share_token_valid?(%Session{status: :cancelled}), do: false
  def share_token_valid?(%Session{status: :completed}), do: false
  
  def share_token_valid?(%Session{date: date}) do
    Date.compare(date, Date.utc_today()) != :lt
  end

  @doc """
  Gets dashboard statistics for the homepage.
  Returns different stats based on whether a user is provided.

  ## For authenticated users
    * sessions_this_month: Number of sessions created this month
    * registrations_this_week: Number of new registrations this week
    * next_session: Next upcoming session

  ## For public users
    * total_sessions: Total number of sessions (all time)
    * total_players: Total number of unique players

  ## Examples

      iex> get_dashboard_stats(user)
      %{sessions_this_month: 5, registrations_this_week: 12, next_session: %Session{}}

      iex> get_dashboard_stats()
      %{total_sessions: 150, total_players: 75}

  """
  def get_dashboard_stats(user \\ nil)

  def get_dashboard_stats(%{id: user_id}) when not is_nil(user_id) do
    # Authenticated trainer stats
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    start_of_week = Date.add(today, -7)

    sessions_this_month =
      Session
      |> where([s], s.user_id == ^user_id)
      |> where([s], s.inserted_at >= ^DateTime.new!(start_of_month, ~T[00:00:00], "Etc/UTC"))
      |> Repo.aggregate(:count)

    registrations_this_week =
      Registration
      |> join(:inner, [r], s in Session, on: r.session_id == s.id)
      |> where([r, s], s.user_id == ^user_id)
      |> where([r], r.registered_at >= ^DateTime.new!(start_of_week, ~T[00:00:00], "Etc/UTC"))
      |> Repo.aggregate(:count)

    next_session =
      Session
      |> where([s], s.user_id == ^user_id)
      |> where([s], s.date >= ^today)
      |> where([s], s.status == :scheduled)
      |> order_by([s], asc: s.date, asc: s.start_time)
      |> limit(1)
      |> Repo.one()

    %{
      sessions_this_month: sessions_this_month,
      registrations_this_week: registrations_this_week,
      next_session: next_session
    }
  end

  def get_dashboard_stats(nil) do
    # Public stats
    total_sessions = Repo.aggregate(Session, :count)
    total_players = Repo.aggregate(Player, :count)

    %{
      total_sessions: total_sessions,
      total_players: total_players
    }
  end

  ## Registration Management

  @doc """
  Returns the list of registrations for a session.

  ## Options
    * `:status` - Filter by status (:all, :confirmed, :waitlisted, etc.)

  ## Examples

      iex> list_registrations(session)
      [%Registration{}, ...]

      iex> list_registrations(session, :confirmed)
      [%Registration{status: :confirmed}, ...]

  """
  def list_registrations(%Session{} = session, status \\ :all) do
    query =
      Registration
      |> where(session_id: ^session.id)
      |> preload(:player)
      |> order_by([r], [r.position, r.registered_at])

    query =
      if status == :all do
        query
      else
        where(query, status: ^status)
      end

    Repo.all(query)
  end

  @doc """
  Gets a single registration.

  Raises `Ecto.NoResultsError` if the Registration does not exist.
  """
  def get_registration!(id) do
    Registration
    |> Repo.get!(id)
    |> Repo.preload([:session, :player])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking registration changes.
  """
  def change_registration(%Registration{} = registration, attrs \\ %{}) do
    Registration.changeset(registration, attrs)
  end

  @doc """
  Gets a registration by its cancellation token.

  Returns nil if not found.
  """
  def get_registration_by_token(token) do
    Registration
    |> where(cancellation_token: ^token)
    |> Repo.one()
    |> case do
      nil -> nil
      registration -> Repo.preload(registration, [:session, :player])
    end
  end

  @doc """
  Registers a player for a session.

  Checks capacity constraints and either confirms or waitlists the player.
  Generates a cancellation token for the registration.
  Broadcasts a PubSub event after successful registration.

  ## Examples

      iex> register_player(session, player, %{})
      {:ok, %Registration{status: :confirmed}}

      iex> register_player(full_session, player, %{})
      {:ok, %Registration{status: :waitlisted}}

      iex> register_player(session, already_registered_player, %{})
      {:error, :already_registered}
  """
  def register_player(%Session{} = session, %Player{} = player, attrs \\ %{}) do
    # Check if player is already registered
    existing =
      Registration
      |> where(session_id: ^session.id, player_id: ^player.id)
      |> where([r], r.status in [:confirmed, :waitlisted])
      |> Repo.one()

    if existing do
      {:error, :already_registered}
    else
      # Get capacity status to determine if player should be confirmed or waitlisted
      capacity_status = get_capacity_status(session)

      # Determine registration status and priority
      {status, priority_score} =
        if capacity_status.can_add_player do
          {:confirmed, nil}
        else
          # Calculate priority for waitlist
          priority = PriorityCalculator.calculate_priority(player, session)
          {:waitlisted, priority}
        end

      # Generate cancellation token
      cancellation_token = RegistrationToken.generate_cancellation_token()

      # Build registration attributes
      registration_attrs =
        attrs
        |> Map.put("session_id", session.id)
        |> Map.put("player_id", player.id)
        |> Map.put("status", status)
        |> Map.put("cancellation_token", cancellation_token)
        |> Map.put("priority_score", priority_score)

      # Create registration
      result =
        %Registration{}
        |> Registration.create_changeset(registration_attrs)
        |> Repo.insert()

      case result do
        {:ok, registration} ->
          # Broadcast PubSub event
          broadcast_session_update(session.id, :player_registered, %{
            player_id: player.id,
            status: status
          })

          {:ok, Repo.preload(registration, [:session, :player])}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Cancels a registration.

  Validates the cancellation deadline and promotes the next player from
  the waitlist if the cancelled registration was confirmed.

  ## Examples

      iex> cancel_registration(registration, session)
      {:ok, %Registration{status: :cancelled}}

      iex> cancel_registration(past_deadline_registration, session)
      {:error, :past_deadline}
  """
  def cancel_registration(%Registration{} = registration, reason \\ nil) do
    # Load session if not preloaded
    registration = Repo.preload(registration, :session)
    session = registration.session

    # Check cancellation deadline
    if RegistrationToken.token_expired?(session) do
      {:error, :past_deadline}
    else
      was_confirmed = registration.status == :confirmed

      # Update registration to cancelled
      result =
        registration
        |> Registration.changeset(%{
          status: :cancelled,
          notes: reason
        })
        |> Repo.update()

      case result do
        {:ok, updated_registration} ->
          # If this was a confirmed registration, promote from waitlist
          if was_confirmed do
            promote_next_from_waitlist(session)
          end

          # Broadcast PubSub event
          broadcast_session_update(session.id, :player_cancelled, %{
            player_id: registration.player_id,
            was_confirmed: was_confirmed
          })

          {:ok, updated_registration}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Promotes the next player from the waitlist to confirmed status.

  Players are promoted in priority score order (highest first).

  ## Examples

      iex> promote_next_from_waitlist(session)
      {:ok, %Registration{status: :confirmed}}

      iex> promote_next_from_waitlist(session_with_no_waitlist)
      {:ok, nil}
  """
  def promote_next_from_waitlist(%Session{} = session, player_id \\ nil) do
    capacity_status = get_capacity_status(session)

    # Debug logging
    require Logger
    Logger.info("Attempting to promote from waitlist. Session #{session.id}, can_add_player: #{capacity_status.can_add_player}, confirmed: #{capacity_status.confirmed}")

    # Only promote if we can add a player
    if capacity_status.can_add_player do
      # Get waitlist
      waitlist =
        Registration
        |> where(session_id: ^session.id, status: :waitlisted)
        |> order_by([r], desc: r.priority_score, asc: r.registered_at)
        |> Repo.all()

      Logger.info("Waitlist has #{length(waitlist)} players")

      # Find the registration to promote
      to_promote =
        if player_id do
          Enum.find(waitlist, &(&1.player_id == player_id))
        else
          List.first(waitlist)
        end

      case to_promote do
        nil ->
          Logger.info("No player to promote")
          {:ok, nil}

        registration ->
          Logger.info("Promoting player #{registration.player_id}")
          result =
            registration
            |> Registration.changeset(%{status: :confirmed})
            |> Repo.update()

          case result do
            {:ok, updated_registration} ->
              # Broadcast PubSub event
              broadcast_session_update(session.id, :player_promoted, %{
                player_id: registration.player_id
              })

              Logger.info("Successfully promoted player #{registration.player_id}")
              {:ok, Repo.preload(updated_registration, [:session, :player])}

            {:error, changeset} ->
              Logger.error("Failed to promote player: #{inspect(changeset.errors)}")
              {:error, changeset}
          end
      end
    else
      Logger.info("Cannot add player - session at capacity")
      {:ok, nil}
    end
  end

  @doc """
  Marks a registration as attended or no-show.

  Updates player statistics after marking attendance.

  ## Examples

      iex> mark_attendance(registration, :attended)
      {:ok, %Registration{status: :attended}}

      iex> mark_attendance(registration, :no_show)
      {:ok, %Registration{status: :no_show}}
  """
  def mark_attendance(%Registration{} = registration, status)
      when status in [:attended, :no_show] do
    registration = Repo.preload(registration, [:player, :session])
    
    result =
      registration
      |> Registration.changeset(%{status: status})
      |> Repo.update()

    case result do
      {:ok, updated_registration} ->
        # Update player stats
        update_player_stats_after_attendance(updated_registration)
        
        # Broadcast PubSub event
        broadcast_session_update(registration.session_id, :attendance_marked, %{
          registration_id: registration.id,
          player_id: registration.player_id,
          status: status
        })

        {:ok, Repo.preload(updated_registration, [:session, :player])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Marks attendance for multiple registrations at once.

  ## Examples

      iex> bulk_mark_attendance(session, [registration_id1, registration_id2], :attended)
      {:ok, 2}
  """
  def bulk_mark_attendance(%Session{} = session, registration_ids, status)
      when status in [:attended, :no_show] do
    # Get all registrations for the session
    registrations =
      Registration
      |> where(session_id: ^session.id)
      |> where([r], r.id in ^registration_ids)
      |> where(status: :confirmed)
      |> Repo.all()

    # Update each registration
    results =
      Enum.map(registrations, fn registration ->
        mark_attendance(registration, status)
      end)

    # Count successful updates
    success_count =
      Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    {:ok, success_count}
  end

  @doc """
  Updates player statistics after attendance is marked.

  Increments total_attendance for attended sessions and total_no_shows for no-shows.
  Updates last_attendance_date for attended sessions.
  """
  def update_player_stats_after_attendance(%Registration{} = registration) do
    registration = Repo.preload(registration, [:player, :session])
    player = registration.player

    case registration.status do
      :attended ->
        update_player(player, %{
          total_attendance: player.total_attendance + 1,
          last_attendance_date: registration.session.date
        })

      :no_show ->
        update_player(player, %{
          total_no_shows: player.total_no_shows + 1
        })

      _ ->
        {:ok, player}
    end
  end

  @doc """
  Gets attendance statistics for a session.

  Returns counts of attended, no-shows, and pending check-ins,
  along with calculated attendance rate.

  ## Examples

      iex> get_session_attendance_stats(session)
      %{
        total_confirmed: 15,
        attended: 12,
        no_shows: 2,
        pending: 1,
        attendance_rate: 85.7
      }

  """
  def get_session_attendance_stats(%Session{} = session) do
    registrations = list_registrations(session, :all)

    total_confirmed = Enum.count(registrations, &(&1.status in [:confirmed, :attended, :no_show]))
    attended = Enum.count(registrations, &(&1.status == :attended))
    no_shows = Enum.count(registrations, &(&1.status == :no_show))
    pending = Enum.count(registrations, &(&1.status == :confirmed))

    attendance_rate =
      if total_confirmed > 0 do
        Float.round(attended / total_confirmed * 100, 1)
      else
        0.0
      end

    %{
      total_confirmed: total_confirmed,
      attended: attended,
      no_shows: no_shows,
      pending: pending,
      attendance_rate: attendance_rate
    }
  end

  # Broadcasts a session update via PubSub
  defp broadcast_session_update(session_id, event, payload) do
    Phoenix.PubSub.broadcast(
      Sideout.PubSub,
      "sessions:#{session_id}",
      {event, payload}
    )
  end

  ## Capacity Management

  @doc """
  Gets the capacity status for a session.

  Returns a map with:
  - confirmed: count of confirmed registrations
  - waitlist: count of waitlisted registrations
  - can_add_player: boolean indicating if more players can be confirmed
  - constraints_satisfied: boolean indicating if all constraints are met
  - unsatisfied_constraints: list of constraints not currently met
  - description: human-readable description of all constraints

  ## Examples

      iex> get_capacity_status(session)
      %{
        confirmed: 15,
        waitlist: 3,
        can_add_player: true,
        constraints_satisfied: true,
        unsatisfied_constraints: [],
        description: "Maximum 18 players, Minimum 12 players required"
      }

  """
  def get_capacity_status(%Session{} = session) do
    constraints =
      ConstraintResolver.parse_constraints(
        session.capacity_constraints,
        session.fields_available
      )

    registrations = list_registrations(session)
    confirmed = Enum.count(registrations, &(&1.status == :confirmed))
    waitlisted = Enum.count(registrations, &(&1.status == :waitlisted))

    session_state = %{
      confirmed_count: confirmed,
      waitlist_count: waitlisted,
      fields_available: session.fields_available
    }

    can_add = ConstraintResolver.can_add_player?(constraints, session_state)
    satisfied = ConstraintResolver.all_satisfied?(constraints, session_state)
    unsatisfied = ConstraintResolver.unsatisfied_constraints(constraints, session_state)

    %{
      confirmed: confirmed,
      waitlist: waitlisted,
      can_add_player: can_add,
      constraints_satisfied: satisfied,
      unsatisfied_constraints: unsatisfied,
      description: ConstraintResolver.describe_constraints(constraints)
    }
  end

  @doc """
  Gets the maximum capacity for a session based on its constraints.
  
  Returns the max capacity value from MaxCapacityConstraint if present,
  otherwise returns a default value of 999 (unlimited).

  ## Examples

      iex> get_max_capacity(session)
      18

  """
  def get_max_capacity(%Session{} = session) do
    constraints =
      ConstraintResolver.parse_constraints(
        session.capacity_constraints,
        session.fields_available
      )

    # Find MaxCapacityConstraint and extract its value
    max_constraint = Enum.find(constraints, fn
      %Sideout.Scheduling.Constraints.MaxCapacityConstraint{} -> true
      _ -> false
    end)

    case max_constraint do
      %{value: max} -> max
      _ -> 999  # Default unlimited capacity
    end
  end

  @doc """
  Checks if a player can register for a session.

  Returns `{:ok, :confirmed}` if the player can be confirmed immediately,
  or `{:ok, :waitlisted}` if they should be waitlisted.

  ## Examples

      iex> can_register?(session)
      {:ok, :confirmed}

      iex> can_register?(full_session)
      {:ok, :waitlisted}

  """
  def can_register?(%Session{} = session) do
    status = get_capacity_status(session)

    if status.can_add_player do
      {:ok, :confirmed}
    else
      {:ok, :waitlisted}
    end
  end
end
