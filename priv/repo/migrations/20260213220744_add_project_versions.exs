defmodule Supabom.Repo.Migrations.AddProjectVersions do
  use Ecto.Migration

  def up do
    # Create project_versions table
    create table(:project_versions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :project_id, references(:projects, type: :uuid, on_delete: :delete_all), null: false
      add :version_number, :integer, null: false
      add :project_version, :text
      add :elixir_version, :text
      add :uploaded_at, :utc_datetime_usec, null: false

      timestamps()
    end

    create index(:project_versions, [:project_id])
    create unique_index(:project_versions, [:project_id, :version_number])

    # Add project_version_id to dependencies
    alter table(:project_dependencies) do
      add :project_version_id, references(:project_versions, type: :uuid, on_delete: :delete_all)
    end

    create index(:project_dependencies, [:project_version_id])

    # Migrate existing projects to version 1
    execute("""
      INSERT INTO project_versions (id, project_id, version_number, project_version, elixir_version, uploaded_at, inserted_at, updated_at)
      SELECT
        gen_random_uuid(),
        id,
        1,
        project_version,
        elixir_version,
        inserted_at,
        inserted_at,
        updated_at
      FROM projects
    """)

    # Link existing dependencies to their version 1
    execute("""
      UPDATE project_dependencies pd
      SET project_version_id = pv.id
      FROM project_versions pv
      WHERE pd.project_id = pv.project_id
        AND pv.version_number = 1
    """)
  end

  def down do
    alter table(:project_dependencies) do
      remove :project_version_id
    end

    drop table(:project_versions)
  end
end
