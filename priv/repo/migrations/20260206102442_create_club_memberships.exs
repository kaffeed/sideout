defmodule Sideout.Repo.Migrations.CreateClubMemberships do
  use Ecto.Migration

  def change do
    create table(:club_memberships) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :club_id, references(:clubs, on_delete: :delete_all), null: false
      add :role, :string, default: "trainer", null: false
      add :status, :string, default: "pending", null: false
      add :requested_at, :utc_datetime, null: false
      add :approved_at, :utc_datetime
      add :approved_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:club_memberships, [:user_id, :club_id])
    create index(:club_memberships, [:user_id])
    create index(:club_memberships, [:club_id])
    create index(:club_memberships, [:status])
  end
end
