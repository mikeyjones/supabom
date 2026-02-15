defmodule Supabom.Projects.Project do
  @moduledoc """
  Project resource for storing uploaded dependency manifests.
  """

  use Ash.Resource,
    domain: Supabom.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("projects")
    repo(Supabom.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :ecosystem, :string do
      allow_nil?(false)
      default("elixir")
      public?(true)
    end

    attribute :user_id, :uuid do
      allow_nil?(true)
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

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many(:dependencies, Supabom.Projects.Dependency)

    has_many :versions, Supabom.Projects.ProjectVersion do
      sort(version_number: :desc)
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :ecosystem, :user_id, :project_version, :elixir_version])
      primary?(true)
    end

    update :update do
      accept([:name, :ecosystem])
      primary?(true)
    end
  end
end
