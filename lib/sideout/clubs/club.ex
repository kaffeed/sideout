defmodule Sideout.Clubs.Club do
  use Ecto.Schema
  import Ecto.Changeset

  schema "clubs" do
    field :name, :string
    field :description, :string
    field :settings, :map, default: %{}

    belongs_to :created_by, Sideout.Accounts.User
    has_many :club_memberships, Sideout.Clubs.ClubMembership
    has_many :members, through: [:club_memberships, :user]
    has_many :sessions, Sideout.Scheduling.Session
    has_many :session_templates, Sideout.Scheduling.SessionTemplate
    has_many :players, Sideout.Scheduling.Player
    has_many :guest_sessions, Sideout.Scheduling.SessionGuestClub

    timestamps()
  end

  @doc false
  def changeset(club, attrs) do
    club
    |> cast(attrs, [:name, :description, :settings, :created_by_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
  end
end
