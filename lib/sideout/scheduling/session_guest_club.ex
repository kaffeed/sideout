defmodule Sideout.Scheduling.SessionGuestClub do
  use Ecto.Schema
  import Ecto.Changeset

  schema "session_guest_clubs" do
    field :invited_at, :utc_datetime

    belongs_to :session, Sideout.Scheduling.Session
    belongs_to :club, Sideout.Clubs.Club
    belongs_to :invited_by, Sideout.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(guest_club, attrs) do
    guest_club
    |> cast(attrs, [:session_id, :club_id, :invited_by_id, :invited_at])
    |> validate_required([:session_id, :club_id])
    |> put_invited_at()
    |> unique_constraint([:session_id, :club_id])
  end

  defp put_invited_at(changeset) do
    if get_field(changeset, :invited_at) do
      changeset
    else
      put_change(changeset, :invited_at, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end
end
