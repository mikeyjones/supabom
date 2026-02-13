defmodule Supabom.Projects.Dependency do
  @moduledoc """
  Parsed dependency entry from an uploaded lockfile.
  """

  use Ash.Resource,
    domain: Supabom.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("project_dependencies")
    repo(Supabom.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :package, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :version, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :manager, :string do
      allow_nil?(false)
      default("hex")
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
      accept([:package, :version, :manager, :project_id])
      primary?(true)
    end

    update :update do
      accept([:package, :version, :manager])
      primary?(true)
    end
  end
end
