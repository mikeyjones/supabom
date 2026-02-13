defmodule Supabom.Repo.Migrations.AddVersionFieldsToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :project_version, :string
      add :elixir_version, :string
    end
  end
end
