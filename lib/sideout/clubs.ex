defmodule Sideout.Clubs do
  @moduledoc """
  Context for managing clubs and memberships.
  """

  import Ecto.Query, warn: false
  alias Sideout.Repo
  alias Sideout.Clubs.{Club, ClubMembership}

  ## Club Management

  @doc """
  Returns the list of clubs.
  """
  def list_clubs do
    Repo.all(Club)
  end

  @doc """
  Returns the list of clubs for a specific user (active memberships only).
  """
  def list_clubs_for_user(user_id) do
    from(m in ClubMembership,
      join: c in Club,
      on: m.club_id == c.id,
      where: m.user_id == ^user_id and m.status == "active",
      order_by: [asc: c.name],
      preload: [club: c]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single club.

  Raises `Ecto.NoResultsError` if the Club does not exist.
  """
  def get_club!(id), do: Repo.get!(Club, id)

  @doc """
  Gets a single club with preloaded members.
  """
  def get_club_with_members(id) do
    Club
    |> Repo.get!(id)
    |> Repo.preload(club_memberships: [:user, :approved_by])
  end

  @doc """
  Creates a club.

  The user who creates the club automatically becomes an admin.
  """
  def create_club(user_id, attrs) do
    %Club{}
    |> Club.changeset(Map.put(attrs, "created_by_id", user_id))
    |> Repo.insert()
    |> case do
      {:ok, club} ->
        # Add creator as admin
        add_trainer_to_club(user_id, club.id, role: "admin", status: "active")
        {:ok, club}

      error -> error
    end
  end

  @doc """
  Updates a club.
  """
  def update_club(%Club{} = club, attrs) do
    club
    |> Club.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a club.
  """
  def delete_club(%Club{} = club) do
    Repo.delete(club)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking club changes.
  """
  def change_club(%Club{} = club, attrs \\ %{}) do
    Club.changeset(club, attrs)
  end

  ## Membership Management

  @doc """
  Requests membership to a club.

  Creates a pending membership request that must be approved by a club admin.
  """
  def request_membership(user_id, club_id) do
    %ClubMembership{}
    |> ClubMembership.changeset(%{
      user_id: user_id,
      club_id: club_id,
      role: "trainer",
      status: "pending"
    })
    |> Repo.insert()
  end

  @doc """
  Approves a pending membership request.
  """
  def approve_membership(membership_id, admin_user_id) do
    membership = Repo.get!(ClubMembership, membership_id)
    
    # Check if the user is an admin of the club
    unless is_club_admin?(admin_user_id, membership.club_id) do
      {:error, :unauthorized}
    else
      membership
      |> ClubMembership.changeset(%{
        status: "active",
        approved_at: DateTime.utc_now() |> DateTime.truncate(:second),
        approved_by_id: admin_user_id
      })
      |> Repo.update()
    end
  end

  @doc """
  Rejects a pending membership request.
  """
  def reject_membership(membership_id, admin_user_id) do
    membership = Repo.get!(ClubMembership, membership_id)
    
    # Check if the user is an admin of the club
    unless is_club_admin?(admin_user_id, membership.club_id) do
      {:error, :unauthorized}
    else
      membership
      |> ClubMembership.changeset(%{
        status: "rejected",
        approved_by_id: admin_user_id
      })
      |> Repo.update()
    end
  end

  @doc """
  Adds a trainer to a club with optional role and status.

  Options:
    - `:role` - "trainer" (default) or "admin"
    - `:status` - "pending" (default), "active", or "rejected"
  """
  def add_trainer_to_club(user_id, club_id, opts \\ []) do
    role = Keyword.get(opts, :role, "trainer")
    status = Keyword.get(opts, :status, "pending")

    %ClubMembership{}
    |> ClubMembership.changeset(%{
      user_id: user_id,
      club_id: club_id,
      role: role,
      status: status
    })
    |> Repo.insert()
  end

  @doc """
  Removes a member from a club.
  """
  def remove_member(club_id, user_id) do
    from(m in ClubMembership,
      where: m.club_id == ^club_id and m.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Promotes a trainer to admin.
  """
  def promote_to_admin(club_id, user_id) do
    from(m in ClubMembership,
      where: m.club_id == ^club_id and m.user_id == ^user_id
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      membership ->
        membership
        |> ClubMembership.changeset(%{role: "admin"})
        |> Repo.update()
    end
  end

  @doc """
  Demotes an admin to trainer.
  """
  def demote_to_trainer(club_id, user_id) do
    from(m in ClubMembership,
      where: m.club_id == ^club_id and m.user_id == ^user_id
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      membership ->
        membership
        |> ClubMembership.changeset(%{role: "trainer"})
        |> Repo.update()
    end
  end

  @doc """
  Lists all active members of a club.
  """
  def list_members(club_id) do
    from(m in ClubMembership,
      where: m.club_id == ^club_id and m.status == "active",
      preload: [:user],
      order_by: [asc: m.role, asc: m.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists all pending membership requests for a club.
  """
  def list_pending_requests(club_id) do
    from(m in ClubMembership,
      where: m.club_id == ^club_id and m.status == "pending",
      preload: [:user],
      order_by: [asc: m.requested_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists all admins of a club.
  """
  def list_admins(club_id) do
    from(m in ClubMembership,
      where: m.club_id == ^club_id and m.status == "active" and m.role == "admin",
      preload: [:user]
    )
    |> Repo.all()
  end

  ## Authorization Helpers

  @doc """
  Checks if a user is an admin of a club.
  """
  def is_club_admin?(user_id, club_id) do
    from(m in ClubMembership,
      where: m.user_id == ^user_id and m.club_id == ^club_id and
             m.status == "active" and m.role == "admin"
    )
    |> Repo.exists?()
  end

  @doc """
  Checks if a user is a member of a club (any role, must be active).
  """
  def is_club_member?(user_id, club_id) do
    from(m in ClubMembership,
      where: m.user_id == ^user_id and m.club_id == ^club_id and
             m.status == "active"
    )
    |> Repo.exists?()
  end

  @doc """
  Checks if a user can manage a club (currently same as is_club_admin?).
  """
  def can_manage_club?(user_id, club_id) do
    is_club_admin?(user_id, club_id)
  end

  @doc """
  Gets a user's membership record for a club.
  """
  def get_membership(user_id, club_id) do
    from(m in ClubMembership,
      where: m.user_id == ^user_id and m.club_id == ^club_id
    )
    |> Repo.one()
  end

  @doc """
  Gets a membership by ID.
  """
  def get_membership!(id) do
    Repo.get!(ClubMembership, id)
  end
end
