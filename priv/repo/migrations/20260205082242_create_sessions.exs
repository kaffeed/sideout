defmodule Sideout.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :date, :date, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :fields_available, :integer, default: 1, null: false
      # Comma-separated constraint names, e.g. "max_18,min_12,even"
      add :capacity_constraints, :text, null: false
      add :cancellation_deadline_hours, :integer, default: 24, null: false
      add :notes, :text
      add :status, :string, default: "scheduled", null: false
      add :session_template_id, references(:session_templates, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:sessions, [:session_template_id])
    create index(:sessions, [:user_id])
    create index(:sessions, [:date])
    create index(:sessions, [:status])
  end
end
