defmodule Supabom.Accounts do
  @moduledoc """
  The Accounts domain, responsible for authentication and user management.
  """

  use Ash.Domain

  resources do
    resource(Supabom.Accounts.User)
    resource(Supabom.Accounts.Token)
  end
end
