defmodule Sideout.Scheduling.SessionCotrainer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "session_cotrainers" do
    field :added_at, :utc_datetime

    belongs_to :session, Sideout.Scheduling.Session
    belongs_to :user, Sideout.Accounts.User
    belongs_to :added_by, Sideout.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(cotrainer, attrs) do
    cotrainer
    |> cast(attrs, [:session_id, :user_id, :added_by_id, :added_at])
    |> validate_required([:session_id, :user_id])
    |> put_added_at()
    |> unique_constraint([:session_id, :user_id])
  end

  defp put_added_at(changeset) do
    if get_field(changeset, :added_at) do
      changeset
    else
      put_change(changeset, :added_at, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end
end
