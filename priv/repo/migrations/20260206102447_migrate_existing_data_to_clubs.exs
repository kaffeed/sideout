defmodule Sideout.Repo.Migrations.MigrateExistingDataToClubs do
  use Ecto.Migration

  def up do
    # Create a default club for existing data
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    # Insert default club first
    repo().query!("""
    INSERT INTO clubs (name, description, settings, inserted_at, updated_at)
    VALUES ('Default Club', 'Auto-created for existing data', '{}', '#{now}', '#{now}')
    """)
    
    # Get the club ID we just created
    result = repo().query!("SELECT id FROM clubs WHERE name = 'Default Club' ORDER BY id DESC LIMIT 1")
    [[default_club_id]] = result.rows
    
    # Migrate all sessions to the default club
    repo().query!("UPDATE sessions SET club_id = #{default_club_id} WHERE club_id IS NULL")
    
    # Migrate all templates to the default club
    repo().query!("UPDATE session_templates SET club_id = #{default_club_id} WHERE club_id IS NULL")
    
    # Migrate all players to the default club
    repo().query!("UPDATE players SET club_id = #{default_club_id} WHERE club_id IS NULL")
    
    # Add all existing users to the default club as active trainers
    repo().query!("""
    INSERT INTO club_memberships (user_id, club_id, role, status, requested_at, approved_at, inserted_at, updated_at)
    SELECT id, #{default_club_id}, 'trainer', 'active', '#{now}', '#{now}', '#{now}', '#{now}'
    FROM users
    """)
    
    # Make the first user an admin
    repo().query!("""
    UPDATE club_memberships 
    SET role = 'admin' 
    WHERE id = (SELECT MIN(id) FROM club_memberships WHERE club_id = #{default_club_id})
    """)

    # Now make the columns NOT NULL
    alter table(:sessions) do
      modify :club_id, references(:clubs, on_delete: :delete_all), null: false, from: references(:clubs, on_delete: :delete_all)
    end

    alter table(:session_templates) do
      modify :club_id, references(:clubs, on_delete: :delete_all), null: false, from: references(:clubs, on_delete: :delete_all)
    end

    alter table(:players) do
      modify :club_id, references(:clubs, on_delete: :delete_all), null: false, from: references(:clubs, on_delete: :delete_all)
    end
  end

  def down do
    # Make columns nullable again
    alter table(:sessions) do
      modify :club_id, references(:clubs, on_delete: :delete_all), null: true
    end

    alter table(:session_templates) do
      modify :club_id, references(:clubs, on_delete: :delete_all), null: true
    end

    alter table(:players) do
      modify :club_id, references(:clubs, on_delete: :delete_all), null: true
    end

    # Delete the default club (this will cascade delete related records)
    execute "DELETE FROM clubs WHERE name = 'Default Club'"
  end
end
