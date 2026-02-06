defmodule Sideout.Repo.Migrations.AddIsTrainerToRegistrations do
  use Ecto.Migration

  def change do
    alter table(:registrations) do
      add :is_trainer, :boolean, default: false, null: false
    end

    create index(:registrations, [:is_trainer])
  end
end
