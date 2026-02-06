defmodule Sideout.Repo.Migrations.AddClubIdToTables do
  use Ecto.Migration

  def change do
    # Add club_id to sessions
    alter table(:sessions) do
      add :club_id, references(:clubs, on_delete: :delete_all)
    end

    create index(:sessions, [:club_id])

    # Add club_id to session_templates
    alter table(:session_templates) do
      add :club_id, references(:clubs, on_delete: :delete_all)
    end

    create index(:session_templates, [:club_id])

    # Add club_id to players
    alter table(:players) do
      add :club_id, references(:clubs, on_delete: :delete_all)
    end

    create index(:players, [:club_id])
  end
end
