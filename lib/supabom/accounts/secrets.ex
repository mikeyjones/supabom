defmodule Supabom.Accounts.Secrets do
  @moduledoc """
  Secrets module for AshAuthentication token signing and OAuth2 configuration.
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

  def secret_for(
        [:authentication, :strategies, :github, :client_id],
        Supabom.Accounts.User,
        _opts,
        _context
      ) do
    get_github_config(:client_id)
  end

  def secret_for(
        [:authentication, :strategies, :github, :client_secret],
        Supabom.Accounts.User,
        _opts,
        _context
      ) do
    get_github_config(:client_secret)
  end

  def secret_for(
        [:authentication, :strategies, :github, :redirect_uri],
        Supabom.Accounts.User,
        _opts,
        _context
      ) do
    base_url = SupabomWeb.Endpoint.url()
    {:ok, "#{base_url}/auth/user/github/callback"}
  end

  defp get_github_config(key) do
    :supabom
    |> Application.get_env(:github, [])
    |> Keyword.fetch(key)
  end
end
