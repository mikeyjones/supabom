defmodule SupabomWeb.Plugs.AuthPlugs do
  @moduledoc """
  Plugs for authentication and authorization
  """
  import Plug.Conn
  import Phoenix.Controller

  def load_current_user(conn, _opts) do
    # AshAuthentication populates :current_user (based on subject name) on the conn assigns.
    # This helper returns the updated conn, not {:ok, user}.
    AshAuthentication.Plug.Helpers.retrieve_from_session(conn, :supabom)
  end

  def require_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be signed in to access this page.")
      |> redirect(to: "/sign-in")
      |> halt()
    end
  end
end
