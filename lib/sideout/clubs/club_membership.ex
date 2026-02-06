defmodule Sideout.Clubs.ClubMembership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "club_memberships" do
    field :role, :string, default: "trainer"
    field :status, :string, default: "pending"
    field :requested_at, :utc_datetime
    field :approved_at, :utc_datetime

    belongs_to :user, Sideout.Accounts.User
    belongs_to :club, Sideout.Clubs.Club
    belongs_to :approved_by, Sideout.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [
      :user_id,
      :club_id,
      :role,
      :status,
      :requested_at,
      :approved_at,
      :approved_by_id
    ])
    |> validate_required([:user_id, :club_id, :role, :status])
    |> validate_inclusion(:role, ["trainer", "admin"])
    |> validate_inclusion(:status, ["pending", "active", "rejected"])
    |> put_requested_at()
    |> unique_constraint([:user_id, :club_id])
  end

  defp put_requested_at(changeset) do
    if get_field(changeset, :requested_at) do
      changeset
    else
      put_change(changeset, :requested_at, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end
end
