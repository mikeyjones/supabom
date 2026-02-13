defmodule Supabom.Accounts.Secrets do
  @moduledoc """
  Secrets module for AshAuthentication token signing.
  """

  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Supabom.Accounts.User,
        _opts,
        _context
      ) do
    case Application.fetch_env(:supabom, SupabomWeb.Endpoint) do
      {:ok, endpoint_config} ->
        Keyword.fetch(endpoint_config, :secret_key_base)

      :error ->
        :error
    end
  end
end
