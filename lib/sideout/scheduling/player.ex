defmodule Sideout.Scheduling.Player do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sideout.Scheduling.Registration

  schema "players" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :notes, :string
    field :total_attendance, :integer, default: 0
    field :total_registrations, :integer, default: 0
    field :total_no_shows, :integer, default: 0
    field :total_waitlists, :integer, default: 0
    field :last_attendance_date, :date

    belongs_to :club, Sideout.Clubs.Club
    has_many :registrations, Registration

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :email, :phone, :notes, :total_attendance, :total_registrations, :total_no_shows, :total_waitlists, :last_attendance_date, :club_id])
    |> validate_required([:name, :club_id])
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> validate_number(:total_attendance, greater_than_or_equal_to: 0)
    |> validate_number(:total_registrations, greater_than_or_equal_to: 0)
    |> validate_number(:total_no_shows, greater_than_or_equal_to: 0)
    |> validate_number(:total_waitlists, greater_than_or_equal_to: 0)
  end
end
