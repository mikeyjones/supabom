defmodule Supabom.Repo.Migrations.CreateRepositoryConnections do
  use Ecto.Migration

  def change do
    create table(:repository_connections, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :project_id, references(:projects, type: :uuid, on_delete: :delete_all), null: false
      add :provider, :string, null: false, default: "github"
      add :owner, :string, null: false
      add :repo, :string, null: false
      add :installation_id, :bigint
      add :default_branch, :string
      add :sync_status, :string, null: false, default: "pending"
      add :sync_error, :text
      add :last_synced_at, :utc_datetime_usec

      timestamps(type: :utc_datetime)
    end

    create unique_index(:repository_connections, [:project_id])

    create unique_index(
             :repository_connections,
             [:provider, :owner, :repo],
             name: :repository_connections_provider_owner_repo_index
           )

    create index(:repository_connections, [:installation_id])
  end
end
