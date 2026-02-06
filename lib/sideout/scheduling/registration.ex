defmodule Sideout.Scheduling.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sideout.Scheduling.{Session, Player}

  schema "registrations" do
    field :position, :integer
    field :status, Ecto.Enum, values: [:confirmed, :waitlisted, :cancelled, :attended, :no_show], default: :confirmed
    field :priority_score, :decimal
    field :registered_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :cancellation_reason, :string
    field :cancellation_token, :string

    belongs_to :session, Session
    belongs_to :player, Player

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [:status, :priority_score, :position, :registered_at, :cancelled_at, :cancellation_reason, :cancellation_token, :session_id, :player_id])
    |> validate_required([:session_id, :player_id])
    |> validate_number(:priority_score, greater_than_or_equal_to: 0)
    |> validate_number(:position, greater_than: 0)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:player_id)
    |> unique_constraint([:session_id, :player_id], name: :registrations_session_id_player_id_index)
    |> unique_constraint(:cancellation_token)
  end

  @doc """
  Changeset for creating a new registration.
  Sets registered_at to current time if not provided.
  """
  def create_changeset(registration, attrs) do
    attrs = Map.put_new(attrs, "registered_at", DateTime.utc_now())
    changeset(registration, attrs)
  end
end
