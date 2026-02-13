defmodule Supabom.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name, :string, null: false
      add :ecosystem, :string, null: false, default: "elixir"
      add :user_id, :uuid

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:user_id])
  end
end
