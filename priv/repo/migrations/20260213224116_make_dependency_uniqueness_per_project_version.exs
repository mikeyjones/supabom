defmodule Supabom.Repo.Migrations.MakeDependencyUniquenessPerProjectVersion do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:project_dependencies, [:project_id, :package, :version])

    create unique_index(
             :project_dependencies,
             [:project_version_id, :package, :version, :manager],
             name: :project_dependencies_version_package_version_manager_index
           )
  end
end
