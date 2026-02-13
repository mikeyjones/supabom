defmodule Supabom.Repo.Migrations.CreateProjectDependencies do
  use Ecto.Migration

  def change do
    create table(:project_dependencies, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :project_id, references(:projects, type: :uuid, on_delete: :delete_all), null: false
      add :package, :string, null: false
      add :version, :string, null: false
      add :manager, :string, null: false, default: "hex"

      timestamps(type: :utc_datetime)
    end

    create index(:project_dependencies, [:project_id])
    create unique_index(:project_dependencies, [:project_id, :package, :version])
  end
end
