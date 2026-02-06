defmodule Sideout.Authorization do
  @moduledoc """
  Authorization logic for multi-club features.
  
  Provides helper functions to check permissions for various actions
  across clubs, sessions, and players.
  """

  alias Sideout.Clubs
  alias Sideout.Scheduling

  ## Club Permissions

  @doc """
  Checks if a user can manage a club (edit settings, approve members, etc.).
  """
  def can_manage_club?(user, club) do
    Clubs.is_club_admin?(user.id, club.id)
  end

  @doc """
  Checks if a user can view a club's details.
  """
  def can_view_club?(user, club) do
    Clubs.is_club_member?(user.id, club.id)
  end

  @doc """
  Checks if a user can approve membership requests for a club.
  """
  def can_approve_members?(user, club) do
    Clubs.is_club_admin?(user.id, club.id)
  end

  ## Session Permissions

  @doc """
  Checks if a user can create a session in a club.
  """
  def can_create_session?(user, club_id) do
    Clubs.is_club_member?(user.id, club_id)
  end

  @doc """
  Checks if a user can edit a session.
  
  Returns true if the user is the creator or a co-trainer.
  """
  def can_edit_session?(user, session) do
    Scheduling.can_manage_session?(session, user.id)
  end

  @doc """
  Checks if a user can delete a session.
  
  Only the session creator can delete it.
  """
  def can_delete_session?(user, session) do
    session.user_id == user.id
  end

  @doc """
  Checks if a user can manage participants (add, remove, demote).
  
  Returns true if the user is the creator or a co-trainer.
  """
  def can_manage_participants?(user, session) do
    Scheduling.can_manage_session?(session, user.id)
  end

  @doc """
  Checks if a user can add co-trainers to a session.
  
  Only the session creator can add co-trainers.
  """
  def can_add_cotrainer?(user, session) do
    session.user_id == user.id
  end

  @doc """
  Checks if a user can invite guest clubs to a session.
  
  Returns true if the user is the creator or a co-trainer.
  """
  def can_invite_guest_club?(user, session) do
    Scheduling.can_manage_session?(session, user.id)
  end

  ## Player Permissions

  @doc """
  Checks if a user can manage players in a club.
  
  All club members can manage players.
  """
  def can_manage_players?(user, club_id) do
    Clubs.is_club_member?(user.id, club_id)
  end
end
