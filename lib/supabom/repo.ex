defmodule Supabom.Repo do
  use AshPostgres.Repo,
    otp_app: :supabom

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end
