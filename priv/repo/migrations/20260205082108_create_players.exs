defmodule Sideout.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :name, :string, null: false
      add :email, :string
      add :phone, :string
      add :notes, :text
      add :total_attendance, :integer, default: 0, null: false
      add :total_registrations, :integer, default: 0, null: false
      add :total_no_shows, :integer, default: 0, null: false
      add :total_waitlists, :integer, default: 0, null: false
      add :last_attendance_date, :date

      timestamps(type: :utc_datetime)
    end

    create index(:players, [:name])
  end
end
