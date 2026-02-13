defmodule SupabomWeb.DashboardController do
  use SupabomWeb, :controller

  def index(conn, _params) do
    # Get the current user from the session
    current_user = conn.assigns[:current_user]

    render(conn, :index, current_user: current_user)
  end
end
