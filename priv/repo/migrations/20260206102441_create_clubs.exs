defmodule Sideout.Repo.Migrations.CreateClubs do
  use Ecto.Migration

  def change do
    create table(:clubs) do
      add :name, :string, null: false
      add :description, :text
      add :settings, :map, default: %{}
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:clubs, [:created_by_id])
  end
end
