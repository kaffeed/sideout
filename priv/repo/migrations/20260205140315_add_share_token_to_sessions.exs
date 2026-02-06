defmodule Sideout.Repo.Migrations.AddShareTokenToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :share_token, :string, size: 21
    end

    create unique_index(:sessions, [:share_token])
  end
end
