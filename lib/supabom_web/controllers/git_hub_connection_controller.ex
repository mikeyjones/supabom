defmodule SupabomWeb.GitHubConnectionController do
  use SupabomWeb, :controller

  @token_salt "github_install_flow"

  def connect(conn, params) do
    return_to = params["return_to"] || ~p"/projects/new"
    project_id = params["project_id"]
    install_url = Application.get_env(:supabom, :github_app, [])[:install_url]

    if is_binary(install_url) and install_url != "" do
      state =
        Phoenix.Token.sign(SupabomWeb.Endpoint, @token_salt, %{
          "return_to" => return_to,
          "project_id" => project_id
        })

      conn
      |> put_session(:github_install_return_to, return_to)
      |> put_session(:github_install_project_id, project_id)
      |> redirect(external: append_state(install_url, state))
    else
      conn
      |> put_flash(:error, "GitHub App installation URL is not configured")
      |> redirect(to: return_to)
    end
  end

  def callback(conn, %{"installation_id" => installation_id, "state" => state}) do
    return_to = return_to_from_state_or_session(conn, state)
    complete_callback(conn, installation_id, return_to)
  end

  def callback(conn, %{"installation_id" => installation_id}) do
    return_to = get_session(conn, :github_install_return_to) || ~p"/projects/new"
    complete_callback(conn, installation_id, return_to)
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "GitHub installation callback missing required parameters")
    |> redirect(to: ~p"/projects")
  end

  defp append_state(install_url, state) do
    uri = URI.parse(install_url)

    params =
      uri.query
      |> query_to_map()
      |> Map.put("state", state)

    URI.to_string(%{uri | query: URI.encode_query(params)})
  end

  defp query_to_map(nil), do: %{}
  defp query_to_map(query), do: URI.decode_query(query)

  defp return_to_from_state_or_session(conn, state) do
    case Phoenix.Token.verify(SupabomWeb.Endpoint, @token_salt, state, max_age: 600) do
      {:ok, payload} ->
        payload["return_to"] || get_session(conn, :github_install_return_to) || ~p"/projects/new"

      _ ->
        get_session(conn, :github_install_return_to) || ~p"/projects/new"
    end
  end

  defp complete_callback(conn, installation_id, return_to) do
    case Integer.parse(to_string(installation_id)) do
      {installation_id_int, _rest} ->
        conn
        |> put_session(:github_installation_id, installation_id_int)
        |> delete_session(:github_install_return_to)
        |> delete_session(:github_install_project_id)
        |> put_flash(:info, "GitHub App connected successfully")
        |> redirect(to: return_to)

      :error ->
        conn
        |> put_flash(:error, "Invalid GitHub installation callback")
        |> redirect(to: ~p"/projects")
    end
  end
end
