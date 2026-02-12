defmodule Supabom.Repo do
  use Ecto.Repo,
    otp_app: :supabom,
    adapter: Ecto.Adapters.Postgres
end
