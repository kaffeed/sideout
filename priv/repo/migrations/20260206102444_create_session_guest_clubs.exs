defmodule Sideout.Repo.Migrations.CreateSessionGuestClubs do
  use Ecto.Migration

  def change do
    create table(:session_guest_clubs) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :club_id, references(:clubs, on_delete: :delete_all), null: false
      add :invited_by_id, references(:users, on_delete: :nilify_all)
      add :invited_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:session_guest_clubs, [:session_id, :club_id])
    create index(:session_guest_clubs, [:session_id])
    create index(:session_guest_clubs, [:club_id])
  end
end
