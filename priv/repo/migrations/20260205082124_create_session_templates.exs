defmodule Sideout.Repo.Migrations.CreateSessionTemplates do
  use Ecto.Migration

  def change do
    create table(:session_templates) do
      add :name, :string, null: false
      add :day_of_week, :string, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :skill_level, :string, null: false
      add :fields_available, :integer, default: 1, null: false
      # Comma-separated constraint names, e.g. "max_18,min_12,even"
      add :capacity_constraints, :text, null: false
      add :cancellation_deadline_hours, :integer, default: 24, null: false
      add :active, :boolean, default: true, null: false
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:session_templates, [:user_id])
    create index(:session_templates, [:active])
  end
end
