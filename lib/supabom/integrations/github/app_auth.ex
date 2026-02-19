defmodule Supabom.Integrations.GitHub.AppAuth do
  @moduledoc """
  GitHub App authentication helpers.
  """

  @github_api "https://api.github.com"

  @spec installation_token(integer()) :: {:ok, String.t()} | {:error, String.t()}
  def installation_token(installation_id) when is_integer(installation_id) do
    with {:ok, jwt} <- app_jwt(),
         {:ok, response} <-
           Req.post(
             url: "#{@github_api}/app/installations/#{installation_id}/access_tokens",
             headers: github_headers(jwt)
           ),
         {:ok, token} <- token_from_response(response) do
      {:ok, token}
    end
  end

  def installation_token(_), do: {:error, "GitHub installation id is missing"}

  @spec app_jwt() :: {:ok, String.t()} | {:error, String.t()}
  def app_jwt do
    with {:ok, app_id, private_key} <- app_config() do
      now = DateTime.utc_now() |> DateTime.to_unix()

      claims = %{
        "iat" => now - 60,
        "exp" => now + 540,
        "iss" => app_id
      }

      jwk = JOSE.JWK.from_pem(private_key)
      signer = %{"alg" => "RS256"}
      {_, jwt} = JOSE.JWT.sign(jwk, signer, claims) |> JOSE.JWS.compact()
      {:ok, jwt}
    else
      {:error, _} = error -> error
    end
  rescue
    _ -> {:error, "Failed to generate GitHub App JWT"}
  end

  defp app_config do
    app_cfg = Application.get_env(:supabom, :github_app, [])
    app_id = app_cfg[:app_id]
    private_key = app_cfg[:private_key]

    cond do
      is_nil(app_id) or app_id == "" ->
        {:error, "GitHub App is not configured (missing app_id)"}

      is_nil(private_key) or private_key == "" ->
        {:error, "GitHub App is not configured (missing private_key)"}

      true ->
        {:ok, to_string(app_id), String.replace(private_key, "\\n", "\n")}
    end
  end

  defp token_from_response(%Req.Response{status: status, body: %{"token" => token}})
       when status in 200..299 and is_binary(token),
       do: {:ok, token}

  defp token_from_response(%Req.Response{status: status, body: body}) do
    {:error, "Failed to fetch installation token (status #{status}): #{inspect(body)}"}
  end

  defp github_headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/vnd.github+json"},
      {"x-github-api-version", "2022-11-28"}
    ]
  end
end
