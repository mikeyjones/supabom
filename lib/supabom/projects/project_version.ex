defmodule Supabom.Projects.ProjectVersion do
  @moduledoc """
  Project version resource for tracking version history of uploaded dependency manifests.
  """

  use Ash.Resource,
    domain: Supabom.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("project_versions")
    repo(Supabom.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :version_number, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :project_version, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :elixir_version, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :uploaded_at, :utc_datetime_usec do
      default(&DateTime.utc_now/0)
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

    has_many :dependencies, Supabom.Projects.Dependency do
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:project_id, :version_number, :project_version, :elixir_version])
      primary?(true)
    end
  end
end
