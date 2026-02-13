defmodule Supabom.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens, primary_key: false) do
      add :jti, :text, primary_key: true
      add :purpose, :text, null: false
      add :subject, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :extra_data, :map

      timestamps(type: :utc_datetime)
    end

    create index(:tokens, [:subject, :purpose])
  end
end
