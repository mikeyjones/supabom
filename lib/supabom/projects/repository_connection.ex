defmodule Supabom.Projects.RepositoryConnection do
  @moduledoc """
  Stores repository linkage details for importing manifests from source control.
  """

  use Ash.Resource,
    domain: Supabom.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("repository_connections")
    repo(Supabom.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :provider, :string do
      allow_nil?(false)
      default("github")
      public?(true)
    end

    attribute :owner, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :repo, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :installation_id, :integer do
      allow_nil?(true)
      public?(true)
    end

    attribute :default_branch, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :sync_status, :string do
      allow_nil?(false)
      default("pending")
      public?(true)
    end

    attribute :sync_error, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :last_synced_at, :utc_datetime_usec do
      allow_nil?(true)
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :project, Supabom.Projects.Project do
      allow_nil?(false)
      attribute_writable?(true)
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :provider,
        :owner,
        :repo,
        :installation_id,
        :default_branch,
        :sync_status,
        :sync_error,
        :last_synced_at,
        :project_id
      ])

      primary?(true)
    end

    update :update do
      accept([
        :owner,
        :repo,
        :installation_id,
        :default_branch,
        :sync_status,
        :sync_error,
        :last_synced_at
      ])

      primary?(true)
    end
  end
end
