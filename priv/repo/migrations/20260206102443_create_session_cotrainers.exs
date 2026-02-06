defmodule Sideout.Repo.Migrations.CreateSessionCotrainers do
  use Ecto.Migration

  def change do
    create table(:session_cotrainers) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :added_by_id, references(:users, on_delete: :nilify_all)
      add :added_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:session_cotrainers, [:session_id, :user_id])
    create index(:session_cotrainers, [:session_id])
    create index(:session_cotrainers, [:user_id])
  end
end
