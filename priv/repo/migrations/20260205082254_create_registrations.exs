defmodule Sideout.Repo.Migrations.CreateRegistrations do
  use Ecto.Migration

  def change do
    create table(:registrations) do
      add :status, :string, default: "confirmed", null: false
      add :priority_score, :decimal, precision: 10, scale: 2
      add :position, :integer
      add :registered_at, :utc_datetime, null: false
      add :cancelled_at, :utc_datetime
      add :cancellation_reason, :text
      add :cancellation_token, :string
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:registrations, [:session_id])
    create index(:registrations, [:player_id])
    create index(:registrations, [:status])
    create index(:registrations, [:priority_score])
    create unique_index(:registrations, [:cancellation_token])
    create unique_index(:registrations, [:session_id, :player_id])
  end
end
