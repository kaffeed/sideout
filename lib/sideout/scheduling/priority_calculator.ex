defmodule Sideout.Scheduling.PriorityCalculator do
  @moduledoc """
  Calculates priority scores for waitlisted players.
  
  The priority queue uses a hybrid algorithm that considers:
  - Recent attendance (last 4 weeks): Favors players who haven't played recently
  - Days since last attendance: Favors players who haven't played in a while
  - No-show history: Penalizes players with no-shows
  - Waitlist history: Rewards players who have been waitlisted before
  
  Higher score = higher priority for promotion from waitlist.
  """

  import Ecto.Query, warn: false
  alias Sideout.Repo
  alias Sideout.Scheduling.{Player, Session, Registration}

  @doc """
  Calculates priority score for a player relative to a session.
  
  ## Scoring Algorithm
  
  Base score: 100.0
  
  - Attendance factor: (8 - recent_attendance) * 10 (0-80 points)
    Rewards players who have attended fewer sessions recently
    
  - Recency factor: min(days_since_last * 0.5, 30) (0-30 points)
    Rewards players who haven't played in a while
    
  - No-show penalty: total_no_shows * -15 (negative points)
    Heavily penalizes unreliable players
    
  - Waitlist bonus: total_waitlists * 3 (positive points)
    Rewards players who have been patient on waitlists before
  
  ## Examples
  
      iex> calculate_priority(player, session)
      152.5
      
  """
  def calculate_priority(%Player{} = player, %Session{} = _session) do
    recent_attendance = get_recent_attendance(player, weeks: 4)
    days_since_last = days_since_last_attendance(player)
    
    base_score = 100.0
    
    # Favor players who attended less recently (0-80 points)
    # If player attended 0 times: (8 - 0) * 10 = 80 points
    # If player attended 8+ times: (8 - 8) * 10 = 0 points
    attendance_factor = max((8 - recent_attendance) * 10, 0)
    
    # Favor players who haven't played in a while (0-30 points)
    recency_factor = min(days_since_last * 0.5, 30)
    
    # Penalize no-shows heavily (-15 per no-show)
    no_show_penalty = player.total_no_shows * -15
    
    # Reward previous waitlist experiences (+3 per waitlist)
    waitlist_bonus = player.total_waitlists * 3
    
    base_score + attendance_factor + recency_factor + no_show_penalty + waitlist_bonus
  end

  @doc """
  Gets the number of sessions a player attended in the last N weeks.
  
  ## Options
    * `:weeks` - Number of weeks to look back (default: 4)
  
  ## Examples
  
      iex> get_recent_attendance(player, weeks: 4)
      3
      
      iex> get_recent_attendance(player, weeks: 8)
      7
      
  """
  def get_recent_attendance(%Player{} = player, opts \\ []) do
    weeks = Keyword.get(opts, :weeks, 4)
    cutoff_date = Date.utc_today() |> Date.add(-weeks * 7)
    
    Registration
    |> where([r], r.player_id == ^player.id)
    |> where([r], r.status == :attended)
    |> join(:inner, [r], s in assoc(r, :session))
    |> where([r, s], s.date >= ^cutoff_date)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Calculates the number of days since a player last attended a session.
  
  Returns 999 if the player has never attended.
  
  ## Examples
  
      iex> days_since_last_attendance(player)
      14
      
      iex> days_since_last_attendance(new_player)
      999
      
  """
  def days_since_last_attendance(%Player{} = player) do
    case player.last_attendance_date do
      nil -> 999  # Never attended
      date -> Date.diff(Date.utc_today(), date)
    end
  end

  @doc """
  Reorders the waitlist for a session based on priority scores.
  
  Calculates priority scores for all waitlisted players and updates their
  position field accordingly.
  
  Returns {:ok, updated_count} or {:error, reason}
  
  ## Examples
  
      iex> reorder_waitlist(session)
      {:ok, 5}
      
  """
  def reorder_waitlist(%Session{} = session) do
    waitlisted_registrations = 
      Registration
      |> where([r], r.session_id == ^session.id)
      |> where([r], r.status == :waitlisted)
      |> preload(:player)
      |> Repo.all()
    
    # Calculate priority scores and sort
    registrations_with_priority = 
      waitlisted_registrations
      |> Enum.map(fn registration ->
        score = calculate_priority(registration.player, session)
        {registration, score}
      end)
      |> Enum.sort_by(fn {_reg, score} -> score end, :desc)
    
    # Update positions and priority scores
    {results, _} = 
      Enum.map_reduce(registrations_with_priority, 1, fn {registration, score}, position ->
        changeset = 
          Registration.changeset(registration, %{
            priority_score: Decimal.from_float(score),
            position: position
          })
        
        result = Repo.update(changeset)
        {result, position + 1}
      end)
    
    # Check if all updates succeeded
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, length(results)}
    else
      {:error, "Failed to update some registrations"}
    end
  end

  @doc """
  Promotes the next player from the waitlist.
  
  If manual_player_id is provided, promotes that specific player.
  Otherwise, promotes the player with the highest priority score.
  
  Returns {:ok, registration} or {:error, reason}
  
  ## Examples
  
      iex> promote_next_from_waitlist(session)
      {:ok, %Registration{status: :confirmed}}
      
      iex> promote_next_from_waitlist(session, player_id)
      {:ok, %Registration{status: :confirmed}}
      
  """
  def promote_next_from_waitlist(%Session{} = session, manual_player_id \\ nil) do
    registration = 
      if manual_player_id do
        get_waitlisted_registration_for_player(session, manual_player_id)
      else
        get_highest_priority_waitlisted_registration(session)
      end
    
    case registration do
      nil -> {:error, "No waitlisted players to promote"}
      reg -> promote_registration(reg)
    end
  end

  # Private helper functions

  defp get_waitlisted_registration_for_player(%Session{} = session, player_id) do
    Registration
    |> where([r], r.session_id == ^session.id)
    |> where([r], r.player_id == ^player_id)
    |> where([r], r.status == :waitlisted)
    |> preload(:player)
    |> Repo.one()
  end

  defp get_highest_priority_waitlisted_registration(%Session{} = session) do
    Registration
    |> where([r], r.session_id == ^session.id)
    |> where([r], r.status == :waitlisted)
    |> order_by([r], [desc: r.priority_score, asc: r.registered_at])
    |> limit(1)
    |> preload(:player)
    |> Repo.one()
  end

  defp promote_registration(%Registration{} = registration) do
    changeset = Registration.changeset(registration, %{status: :confirmed, position: nil})
    Repo.update(changeset)
  end
end

